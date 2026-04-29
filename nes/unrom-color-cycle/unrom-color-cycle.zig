// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES UNROM colour-cycle: advances the universal BG colour through all 64 NES
//! palette entries.  UNROM (mapper 2) uses CHR RAM; no tile data required.
//! Matches nesdoug colour-cycle ported to UNROM.
const neslib = @import("neslib");
const mapper = @import("mapper");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    mapper.set_prg_bank(0);
    neslib.pal_bg(&(.{0x0f} ** 16));
    neslib.ppu_on_bg();

    var color: u8 = 0;
    while (true) {
        for (0..30) |_| neslib.ppu_wait_nmi(); // ~0.5 s at 60 Hz NTSC
        color = (color +% 1) & 0x3f;
        neslib.pal_col(0, color);
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
