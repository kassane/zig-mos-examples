// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! chr2svg — NES CHR tile data → SVG tile sheet.
//!
//! Usage: chr2svg <input.chr> <output.svg> [--scale N] [--cols N]
//!   --scale N   pixels per NES pixel  (default: 3)
//!   --cols  N   tiles per row         (default: 16)
//!
//! NES CHR format: each 16-byte tile = 8 bytes plane-0 + 8 bytes plane-1.
//! Pixel colour = (plane0_bit << 0) | (plane1_bit << 1) → 0..3.

const std = @import("std");

// Palette: colour-0 is the background (emitted as SVG bg rect, not per-pixel).
const PALETTE = [4][]const u8{
    "#f0f0f0", // 0 – background / transparent
    "#777777", // 1
    "#393939", // 2
    "#000000", // 3
};

// ── CHR decode ────────────────────────────────────────────────────────────────

fn decodePixel(chr: []const u8, tile: usize, row: usize, col: usize) u2 {
    const base = tile * 16;
    const p0 = (chr[base + row] >> @intCast(7 - col)) & 1;
    const p1 = (chr[base + 8 + row] >> @intCast(7 - col)) & 1;
    return @intCast(p0 | (p1 << 1));
}

// ── SVG generation ────────────────────────────────────────────────────────────

fn writeSvg(
    buf: *std.ArrayList(u8),
    alloc: std.mem.Allocator,
    chr: []const u8,
    scale: u32,
    cols: u32,
) !struct { non_empty: u32 } {
    const num_tiles: u32 = @intCast(chr.len / 16);
    const num_rows = (num_tiles + cols - 1) / cols;
    const px = scale;
    const width = cols * 8 * px;
    const height = num_rows * 8 * px;

    // Header
    var tmp: [256]u8 = undefined;
    try buf.appendSlice(alloc, try std.fmt.bufPrint(&tmp,
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<svg xmlns="http://www.w3.org/2000/svg"
        \\     width="{d}" height="{d}" viewBox="0 0 {d} {d}">
        \\
    , .{ width, height, width, height }));

    // Background
    try buf.appendSlice(alloc, try std.fmt.bufPrint(&tmp,
        \\<rect width="{d}" height="{d}" fill="{s}"/>
        \\
    , .{ width, height, PALETTE[0] }));

    // Pixels
    var non_empty: u32 = 0;
    var tile: u32 = 0;
    while (tile < num_tiles) : (tile += 1) {
        const tx = tile % cols;
        const ty = tile / cols;
        var empty = true;
        for (0..8) |row| {
            for (0..8) |col| {
                const c = decodePixel(chr, tile, row, col);
                if (c == 0) continue;
                empty = false;
                const x = tx * 8 * px + col * px;
                const y = ty * 8 * px + row * px;
                try buf.appendSlice(alloc, try std.fmt.bufPrint(
                    &tmp,
                    "<rect x=\"{d}\" y=\"{d}\" width=\"{d}\" height=\"{d}\" fill=\"{s}\"/>\n",
                    .{ x, y, px, px, PALETTE[c] },
                ));
            }
        }
        if (!empty) non_empty += 1;
    }

    // Tile-boundary grid lines (semi-transparent).
    // Vertical lines
    var i: u32 = 0;
    while (i <= cols) : (i += 1) {
        const x = i * 8 * px;
        try buf.appendSlice(alloc, try std.fmt.bufPrint(
            &tmp,
            "<line x1=\"{d}\" y1=\"0\" x2=\"{d}\" y2=\"{d}\" stroke=\"#00000022\" stroke-width=\"1\"/>\n",
            .{ x, x, height },
        ));
    }
    // Horizontal lines
    var j: u32 = 0;
    while (j <= num_rows) : (j += 1) {
        const y = j * 8 * px;
        try buf.appendSlice(alloc, try std.fmt.bufPrint(
            &tmp,
            "<line x1=\"0\" y1=\"{d}\" x2=\"{d}\" y2=\"{d}\" stroke=\"#00000022\" stroke-width=\"1\"/>\n",
            .{ y, width, y },
        ));
    }

    try buf.appendSlice(alloc, "</svg>\n");
    return .{ .non_empty = non_empty };
}

// ── entry point ───────────────────────────────────────────────────────────────

fn usageExit() noreturn {
    std.debug.print("Usage: chr2svg <input.chr> <output.svg> [--scale N] [--cols N]\n", .{});
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
    var scale: u32 = 3;
    var cols: u32 = 16;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--scale")) {
            const s = args.next() orelse usageExit();
            scale = std.fmt.parseInt(u32, s, 10) catch usageExit();
        } else if (std.mem.eql(u8, arg, "--cols")) {
            const c = args.next() orelse usageExit();
            cols = std.fmt.parseInt(u32, c, 10) catch usageExit();
        } else if (in_path == null) {
            in_path = arg;
        } else if (out_path == null) {
            out_path = arg;
        } else usageExit();
    }

    const inp = in_path orelse usageExit();
    const outp = out_path orelse usageExit();

    if (scale == 0 or cols == 0) {
        std.debug.print("chr2svg: --scale and --cols must be > 0\n", .{});
        std.process.exit(1);
    }

    const chr = cwd.readFileAlloc(io, inp, alloc, .unlimited) catch |err| {
        std.debug.print("chr2svg: cannot read {s}: {s}\n", .{ inp, @errorName(err) });
        std.process.exit(1);
    };
    defer alloc.free(chr);

    if (chr.len == 0 or chr.len % 16 != 0) {
        std.debug.print("chr2svg: {s}: invalid CHR size {d} (must be nonzero multiple of 16)\n", .{ inp, chr.len });
        std.process.exit(1);
    }

    var svg_buf: std.ArrayList(u8) = .empty;
    defer svg_buf.deinit(alloc);

    const stats = try writeSvg(&svg_buf, alloc, chr, scale, cols);

    const out_file = try cwd.createFile(io, outp, .{});
    defer out_file.close(io);
    var write_buf: [8192]u8 = undefined;
    var fw = out_file.writer(io, &write_buf);
    try fw.interface.writeAll(svg_buf.items);
    try fw.flush();

    std.debug.print("chr2svg: {d} tiles ({d} non-empty) → {s}\n", .{
        chr.len / 16, stats.non_empty, outp,
    });
}
