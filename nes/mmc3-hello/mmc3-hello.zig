// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES MMC3 mapper hello — solid background colour, mapper register init.
//! MMC3 (mapper 4) supports banked PRG/CHR ROM, configurable mirroring, and
//! a scanline-based IRQ counter.  Uses CHR RAM (no CHR ROM embedded).
//! Uses translated mapper.h (set_prg_8000 / set_prg_a000 / set_mirroring).
const neslib = @import("neslib");
const mapper = @import("mapper");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    // Initialise MMC3: select PRG banks and set vertical mirroring.
    mapper.set_prg_8000(0);
    mapper.set_prg_a000(1);
    mapper.set_mirroring(mapper.MIRROR_VERTICAL);
    const bg_pal: [16]u8 = .{ 0x1C, 0x1C, 0x2C, 0x3C } ++ .{0x00} ** 12;
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
