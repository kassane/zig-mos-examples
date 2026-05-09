// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! MEGA65 hello: writes a greeting to screen RAM and sets the border colour via VIC-IV.
pub const panic = @import("mos_panic");
const std = @import("std");
const mega65 = @import("mega65");

/// VIC-IV register file mapped at $D000.
const vic: *volatile mega65.__vic4 = @ptrFromInt(0xd000);

/// Convert an ASCII string to C64/MEGA65 screen codes at comptime.
/// Uppercase letters A–Z → codes 1–26 (= ASCII - 0x40).
/// Digits, punctuation, space ($20–$3F) → same as ASCII.
fn screenCodes(comptime s: []const u8) [s.len]u8 {
    var out: [s.len]u8 = undefined;
    for (s, 0..) |c, i|
        out[i] = if (std.ascii.isUpper(c)) c - 0x40 else c;
    return out;
}

export fn main() void {
    // 80-column C65/MEGA65 screen RAM at $0800; row 15 (0-indexed 14) is just
    // below the RUN: prompt at offset 14 * 80 = 1120.
    const screen: [*]volatile u8 = @ptrFromInt(0x0800);
    const msg = comptime screenCodes("HELLO, ZIG! WELCOME TO MEGA65.");
    for (msg, 0..) |code, i| screen[14 * 80 + i] = code;
    vic.bordercol = 5; // green border
}
