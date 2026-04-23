// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Apple IIe Sierpiński triangle via midpoint-iteration IFS (hires output placeholder).
const std = @import("std");

var next: u64 = 1;

fn srand(seed: u64) void {
    next = seed;
}

/// LCG pseudo-random number generator (same constants as stdlib rand).
fn rand() u64 {
    next = next *% 1103515245 +% 12345;
    return (next / 65536) % 32768;
}

export fn main() void {
    srand(1);
    var sx = rand() % 280;
    var sy = rand() % 192;

    /// Three attractor points for the Sierpiński IFS: bottom-left, bottom-right, top-centre.
    const attractors = [3][2]u64{
        .{ 0, 192 },
        .{ 280, 192 },
        .{ 140, 0 },
    };

    while (true) {
        const pt = attractors[rand() % 3];
        sx = (sx + pt[0]) / 2;
        sy = (sy + pt[1]) / 2;
        // TODO: hires_plot_on(@intCast(sx), @intCast(sy))
    }
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
