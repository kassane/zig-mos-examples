// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES UNROM mapper hello — solid background colour, explicit PRG bank init.
//! UNROM (mapper 2) switches 16 KiB PRG ROM banks at $8000-$BFFF by writing
//! to $8000-$FFFF.  Uses CHR RAM (no CHR ROM embedded).
//! Uses translated mapper.h (set_prg_bank / get_prg_bank / banked_call).
const neslib = @import("neslib");
const mapper = @import("mapper");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    // Switch to PRG bank 0 explicitly before enabling rendering.
    mapper.set_prg_bank(0);
    const bg_pal: [16]u8 = .{ 0x16, 0x16, 0x27, 0x30 } ++ .{0x00} ** 12;
    neslib.pal_bright(4);
    neslib.pal_bg(&bg_pal);
    neslib.ppu_on_all();
    while (true) {
        neslib.ppu_wait_nmi();
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
