// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Apple IIe Sierpiński triangle via midpoint-iteration IFS on the HIRES page.
const std = @import("std");
const hw = @import("apple2");

var next: u32 = 1;

fn srand(seed: u32) void {
    next = seed;
}

fn rand() u16 {
    next = next *% 1103515245 +% 12345;
    return @truncate(next >> 16);
}

/// Apple IIe HIRES byte address for pixel (x, y): 280×192, page 1 at 0x2000.
fn hiresAddr(x: u16, y: u16) *volatile u8 {
    const row: u16 = (y & 7) * 1024 + ((y >> 3) & 7) * 128 + (y >> 6) * 40 + (x / 7);
    return @ptrFromInt(@as(u16, 0x2000) + row);
}

fn hiresPlot(x: u16, y: u16) void {
    const bit: u3 = @truncate(x % 7);
    hiresAddr(x, y).* |= @as(u8, 1) << bit;
}

export fn main() void {
    // Switch to HIRES full-screen graphics.
    hw.TEXTMODE_GRAPHICS.* = 0;
    hw.MIXEDMODE_OFF.* = 0;
    hw.PAGE_PAGE1.* = 0;
    hw.HIRES_ON.* = 0;

    // Clear HIRES page 1 ($2000-$3FFF) to avoid garbage from previous program.
    var i: u16 = 0;
    while (i < 0x2000) : (i += 1) hw.HIRES_PAGE_1[i] = 0;

    srand(1);
    var sx: u16 = rand() % 280;
    var sy: u16 = rand() % 192;

    const attractors = [3][2]u16{
        .{ 0, 191 },
        .{ 279, 191 },
        .{ 139, 0 },
    };

    while (true) {
        const pt = attractors[rand() % 3];
        sx = (sx + pt[0]) / 2;
        sy = (sy + pt[1]) / 2;
        hiresPlot(sx, sy);
    }
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
