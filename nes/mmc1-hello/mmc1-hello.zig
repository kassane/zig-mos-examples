// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES MMC1 mapper hello — solid background colour, mapper register init.
//! MMC1 (mapper 1) supports banked PRG and CHR ROM and configurable mirroring
//! via a serial shift register.  Uses CHR RAM (no CHR ROM embedded).
//! Uses translated mapper.h (set_prg_bank / set_mirroring / MIRROR_VERTICAL).
const neslib = @import("neslib");
const mapper = @import("mapper");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    // Initialise MMC1: select PRG bank 0 and set vertical mirroring.
    mapper.set_prg_bank(0);
    mapper.set_mirroring(mapper.MIRROR_VERTICAL);
    const bg_pal: [16]u8 = .{ 0x1A, 0x1A, 0x2A, 0x3A } ++ .{0x00} ** 12;
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
