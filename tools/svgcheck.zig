// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! svgcheck — structural checker for chr2svg-generated SVG tile sheets.
//!
//! Usage: svgcheck <file.svg> [file...]
//!
//! Checks: <svg> root with width/height, at least one <rect>, closing </svg>.
//! Reports rect/line counts and file size.
//!
//! Exit code: 0 if all files pass, 1 if any file is missing or malformed.

const std = @import("std");

fn usageExit() noreturn {
    std.debug.print("Usage: svgcheck <file.svg> [file...]\n", .{});
    std.process.exit(1);
}

fn checkSvg(path: []const u8, data: []const u8) bool {
    const svg_pos = std.mem.indexOf(u8, data, "<svg") orelse {
        std.debug.print("{s}: ERROR: no <svg element\n", .{path});
        return false;
    };
    const tag_end = std.mem.indexOfPos(u8, data, svg_pos, ">") orelse {
        std.debug.print("{s}: ERROR: <svg tag not closed\n", .{path});
        return false;
    };
    const svg_tag = data[svg_pos .. tag_end + 1];
    if (std.mem.indexOf(u8, svg_tag, "width=") == null or
        std.mem.indexOf(u8, svg_tag, "height=") == null)
    {
        std.debug.print("{s}: ERROR: <svg missing width/height\n", .{path});
        return false;
    }
    if (std.mem.indexOf(u8, data, "</svg>") == null) {
        std.debug.print("{s}: ERROR: missing </svg>\n", .{path});
        return false;
    }

    var rect_count: u32 = 0;
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, data, pos, "<rect")) |idx| {
        rect_count += 1;
        pos = idx + 5;
    }
    if (rect_count == 0) {
        std.debug.print("{s}: ERROR: no <rect elements\n", .{path});
        return false;
    }

    var line_count: u32 = 0;
    pos = 0;
    while (std.mem.indexOfPos(u8, data, pos, "<line")) |idx| {
        line_count += 1;
        pos = idx + 5;
    }

    // rect_count includes the background rect; the rest are pixel rects.
    std.debug.print("{s}: OK  rects={d} (bg=1 pixels={d})  lines={d}  {d}B\n", .{
        path, rect_count, rect_count - 1, line_count, data.len,
    });
    return true;
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const cwd = std.Io.Dir.cwd();

    var args_iter = try init.minimal.args.iterateAllocator(alloc);
    defer args_iter.deinit();
    _ = args_iter.next();

    var any_arg = false;
    var all_ok = true;

    while (args_iter.next()) |path| {
        any_arg = true;
        const data = cwd.readFileAlloc(io, path, alloc, .unlimited) catch |err| {
            std.debug.print("{s}: ERROR: {s}\n", .{ path, @errorName(err) });
            all_ok = false;
            continue;
        };
        defer alloc.free(data);
        if (!checkSvg(path, data)) all_ok = false;
    }

    if (!any_arg) usageExit();
    if (!all_ok) std.process.exit(1);
}
