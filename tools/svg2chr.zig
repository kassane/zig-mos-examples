// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! svg2chr — SVG tile sheet → NES CHR binary (reverse of chr2svg).
//!
//! Usage: svg2chr <input.svg> <output.chr> [--scale N] [--cols N]
//!   --scale N   pixels per NES pixel  (default: auto-detect from rect size)
//!   --cols  N   tiles per row         (default: derived from SVG width)
//!
//! Reads SVG files produced by chr2svg and reconstructs binary NES CHR data.
//! Pixel colour → 2-bit CHR value via palette match; bit-planes written separately.

const std = @import("std");

const PALETTE = [4][]const u8{
    "#f0f0f0", // 0 – background (skipped)
    "#777777", // 1
    "#393939", // 2
    "#000000", // 3
};

fn paletteIndex(fill: []const u8) ?u2 {
    for (PALETTE, 0..) |p, i| {
        if (std.mem.eql(u8, fill, p)) return @intCast(i);
    }
    return null;
}

fn parseU32(s: []const u8) ?u32 {
    return std.fmt.parseInt(u32, s, 10) catch null;
}

// Extract the value of an XML attribute: name="VALUE" or name='VALUE'.
fn extractAttr(tag: []const u8, name: []const u8) ?[]const u8 {
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, tag, pos, name)) |idx| {
        const after = idx + name.len;
        if (after >= tag.len or tag[after] != '=') {
            pos = after;
            continue;
        }
        const vs = after + 1;
        if (vs >= tag.len) return null;
        const q = tag[vs];
        if (q != '"' and q != '\'') {
            pos = vs;
            continue;
        }
        const cs = vs + 1;
        const end = std.mem.indexOfScalarPos(u8, tag, cs, q) orelse return null;
        return tag[cs..end];
    }
    return null;
}

fn usageExit() noreturn {
    std.debug.print("Usage: svg2chr <input.svg> <output.chr> [--scale N] [--cols N]\n", .{});
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const cwd = std.Io.Dir.cwd();

    var args = try init.minimal.args.iterateAllocator(alloc);
    defer args.deinit();
    _ = args.next();

    var in_path: ?[]const u8 = null;
    var out_path: ?[]const u8 = null;
    var scale_opt: ?u32 = null;
    var cols_opt: ?u32 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--scale")) {
            const s = args.next() orelse usageExit();
            scale_opt = std.fmt.parseInt(u32, s, 10) catch usageExit();
        } else if (std.mem.eql(u8, arg, "--cols")) {
            const c = args.next() orelse usageExit();
            cols_opt = std.fmt.parseInt(u32, c, 10) catch usageExit();
        } else if (in_path == null) {
            in_path = arg;
        } else if (out_path == null) {
            out_path = arg;
        } else usageExit();
    }

    const inp = in_path orelse usageExit();
    const outp = out_path orelse usageExit();

    const svg = cwd.readFileAlloc(io, inp, alloc, .unlimited) catch |err| {
        std.debug.print("svg2chr: cannot read {s}: {s}\n", .{ inp, @errorName(err) });
        std.process.exit(1);
    };
    defer alloc.free(svg);

    // Parse SVG dimensions from the root <svg> element.
    const svg_pos = std.mem.indexOf(u8, svg, "<svg") orelse {
        std.debug.print("svg2chr: {s}: no <svg element\n", .{inp});
        std.process.exit(1);
    };
    const tag_end = std.mem.indexOfPos(u8, svg, svg_pos, ">") orelse {
        std.debug.print("svg2chr: {s}: unclosed <svg tag\n", .{inp});
        std.process.exit(1);
    };
    const svg_tag = svg[svg_pos .. tag_end + 1];

    const w_str = extractAttr(svg_tag, "width") orelse {
        std.debug.print("svg2chr: missing width\n", .{});
        std.process.exit(1);
    };
    const h_str = extractAttr(svg_tag, "height") orelse {
        std.debug.print("svg2chr: missing height\n", .{});
        std.process.exit(1);
    };
    const svg_w = parseU32(w_str) orelse {
        std.debug.print("svg2chr: bad width\n", .{});
        std.process.exit(1);
    };
    const svg_h = parseU32(h_str) orelse {
        std.debug.print("svg2chr: bad height\n", .{});
        std.process.exit(1);
    };

    // Auto-detect scale: find the smallest non-background rect width.
    const scale: u32 = scale_opt orelse blk: {
        var min_w: u32 = std.math.maxInt(u32);
        var pos: usize = 0;
        while (std.mem.indexOfPos(u8, svg, pos, "<rect")) |idx| {
            const re = std.mem.indexOfPos(u8, svg, idx, ">") orelse break;
            const rt = svg[idx .. re + 1];
            pos = re + 1;
            if (extractAttr(rt, "fill")) |fill| {
                if (paletteIndex(fill)) |ci| {
                    if (ci != 0) {
                        if (parseU32(extractAttr(rt, "width") orelse "0")) |rw| {
                            if (rw > 0 and rw < min_w) min_w = rw;
                        }
                    }
                }
            }
        }
        break :blk if (min_w != std.math.maxInt(u32)) min_w else 3;
    };

    const cols: u32 = cols_opt orelse @divTrunc(svg_w, 8 * scale);

    if (scale == 0 or cols == 0) {
        std.debug.print("svg2chr: cannot determine scale/cols (scale={d} cols={d})\n", .{ scale, cols });
        std.process.exit(1);
    }

    const tile_rows: u32 = @divTrunc(svg_h, 8 * scale);
    const num_tiles: u32 = cols * tile_rows;

    if (num_tiles == 0) {
        std.debug.print("svg2chr: 0 tiles computed (scale={d} cols={d} svg={d}x{d})\n", .{ scale, cols, svg_w, svg_h });
        std.process.exit(1);
    }

    // Allocate zeroed CHR buffer (16 bytes/tile).
    const chr = try alloc.alloc(u8, num_tiles * 16);
    defer alloc.free(chr);
    @memset(chr, 0);

    // Scan all <rect> elements and encode pixels into bit-planes.
    var pixel_count: u32 = 0;
    {
        var pos: usize = 0;
        while (std.mem.indexOfPos(u8, svg, pos, "<rect")) |idx| {
            const re = std.mem.indexOfPos(u8, svg, idx, ">") orelse break;
            const rt = svg[idx .. re + 1];
            pos = re + 1;

            const fill = extractAttr(rt, "fill") orelse continue;
            const ci = paletteIndex(fill) orelse continue;
            if (ci == 0) continue; // background — skip

            const rx = parseU32(extractAttr(rt, "x") orelse continue) orelse continue;
            const ry = parseU32(extractAttr(rt, "y") orelse continue) orelse continue;

            // Convert SVG coordinates to NES tile/row/col.
            const nx = @divTrunc(rx, scale);
            const ny = @divTrunc(ry, scale);
            const tile_x = @divTrunc(nx, 8);
            const tile_y = @divTrunc(ny, 8);
            const tile = tile_y * cols + tile_x;
            const row = ny % 8;
            const col = nx % 8;

            if (tile >= num_tiles) continue;

            const base: usize = tile * 16;
            const bit: u8 = @as(u8, 1) << @intCast(7 - col);
            if (ci & 1 != 0) chr[base + row] |= bit; // plane 0
            if (ci & 2 != 0) chr[base + 8 + row] |= bit; // plane 1
            pixel_count += 1;
        }
    }

    const out_file = try cwd.createFile(io, outp, .{});
    defer out_file.close(io);
    var write_buf: [8192]u8 = undefined;
    var fw = out_file.writer(io, &write_buf);
    try fw.interface.writeAll(chr);
    try fw.flush();

    std.debug.print("svg2chr: {d} tiles ({d} colored pixels) → {s}\n", .{
        num_tiles, pixel_count, outp,
    });
}
