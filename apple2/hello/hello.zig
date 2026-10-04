// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Apple IIe ProDOS hello — port of llvm-mos-sdk PR #444
//! print one line, then idle so the output
//! stays on the text page.
pub const panic = @import("mos_panic");

const std = @import("std");

pub const std_options: std.Options = .{ .logFn = logFn };

/// mos has no usable std I/O backend (`std.debug.print` needs one), so render
/// the line through std.fmt and flush it with libc stdio instead.
fn logFn(comptime level: std.log.Level, comptime scope: @EnumLiteral(), comptime format: []const u8, args: anytype) void {
    _ = level;
    _ = scope;
    const msg = comptime std.fmt.comptimePrint(format ++ "\n", args);
    _ = std.c.printf("%s", msg.ptr);
}

pub export fn main() callconv(.c) void {
    std.log.info("hello, apple ii", .{});
    while (true) {}
}
