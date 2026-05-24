// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! MEGA65 picolibc demo: exercises string.h functions from picolibc.
pub const panic = @import("mos_panic");

const std = @import("std");
const mega65 = @import("mega65");

const vic: *volatile mega65.__vic4 = @ptrFromInt(0xd000);
const screen: [*]volatile u8 = @ptrFromInt(0x0800);
const pc = @import("picolibc");

fn screenCode(c: u8) u8 {
    return if (std.ascii.isUpper(c)) c - 0x40 else c;
}

fn writeLine(row: u8, msg: []const u8) void {
    const base = @as(usize, row) * 80;
    for (msg, 0..) |c, i| screen[base + i] = screenCode(c);
}

fn u8ToScreenBuf(v: u8, buf: []u8) []u8 {
    if (v == 0) {
        buf[0] = '0';
        return buf[0..1];
    }
    var i: usize = 0;
    var n = v;
    while (n > 0) : (n /= 10) {
        buf[i] = '0' + n % 10;
        i += 1;
    }
    // reverse
    var lo: usize = 0;
    var hi = i;
    while (lo < hi) {
        hi -= 1;
        const tmp = buf[lo];
        buf[lo] = buf[hi];
        buf[hi] = tmp;
        lo += 1;
    }
    return buf[0..i];
}

export fn main() void {
    const s = "picolibc";
    const n: u8 = @truncate(pc.strlen(s));
    var nbuf: [3]u8 = undefined;
    const nstr = u8ToScreenBuf(n, &nbuf);

    var line0: [80]u8 = undefined;
    @memset(&line0, ' ');
    @memcpy(line0[0..16], "PICOLIBC STRLEN=");
    @memcpy(line0[16..][0..nstr.len], nstr);
    writeLine(12, &line0);

    const r: c_int = pc.strcmp("abc", "abc");
    var rbuf: [3]u8 = undefined;
    const rstr = u8ToScreenBuf(@intCast(r), &rbuf);

    var line1: [80]u8 = undefined;
    @memset(&line1, ' ');
    @memcpy(line1[0..16], "STRCMP ABC ABC= ");
    @memcpy(line1[16..][0..rstr.len], rstr);
    writeLine(13, &line1);

    vic.bordercol = 14; // light blue border
}
