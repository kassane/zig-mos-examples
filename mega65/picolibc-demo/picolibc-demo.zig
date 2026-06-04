// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! MEGA65 picolibc demo: exercises the copy family from picolibc.
pub const panic = @import("mos_panic");

const std = @import("std");
const mega65 = @import("mega65");
const pc = @import("picolibc");

const vic: *volatile mega65.__vic4 = @ptrFromInt(0xd000);
const screen: [*]volatile u8 = @ptrFromInt(0x0800);

fn screenCodes(comptime s: []const u8) [s.len]u8 {
    var out: [s.len]u8 = undefined;
    for (s, 0..) |c, i|
        out[i] = if (std.ascii.isUpper(c)) c - 0x40 else c;
    return out;
}

/// Write a compile-time string to the 80-column screen ($0800) at row/col.
/// Mirrors the minimal mega65-hello pattern (no large stack buffers).
fn writeAt(row: u8, col: u8, comptime s: []const u8) void {
    const codes = comptime screenCodes(s);
    const base = @as(usize, row) * 80 + col;
    for (codes, 0..) |c, i| screen[base + i] = c;
}

var buf: [9]u8 = undefined;
var ov: [12]u8 = undefined;

export fn main() void {
    // strncpy: copy exactly 8 bytes of "picolibc" into a fresh buffer.
    _ = pc.strncpy(&buf, "picolibc", 8);
    buf[8] = 0;
    const ncpy_ok = pc.strncmp(&buf, "picolibc", 8) == 0;

    // memmove: shift "picolibc" right by 4 within an overlapping buffer.
    _ = pc.memcpy(&ov, "picolibc\x00\x00\x00\x00", 12);
    _ = pc.memmove(ov[4..].ptr, &ov, 8); // overlapping forward move
    const move_ok = ov[4] == 'p' and ov[11] == 'c';

    writeAt(14, 0, "STRNCPY ");
    if (ncpy_ok) writeAt(14, 8, "OK") else writeAt(14, 8, "NO");
    writeAt(15, 0, "MEMMOVE ");
    if (move_ok) writeAt(15, 8, "OK") else writeAt(15, 8, "NO");

    vic.bordercol = 14; // light blue border
}
