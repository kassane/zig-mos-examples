// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES GTROM mapper hello — solid background colour, mapper register init.
//! GTROM (mapper 111) is a self-made cartridge board with 512 KiB PRG-ROM,
//! 16 KiB CHR-RAM, and unique features: 2 CHR banks, 2 nametable banks, and
//! green/red LEDs on the PCB itself.
//! Uses translated mapper.h (set_prg_bank / set_chr_bank / set_nt_bank).
const neslib = @import("neslib");
const mapper = @import("mapper");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    // Initialise GTROM: select PRG bank 0, CHR bank 0, nametable bank 0.
    _ = mapper.set_prg_bank(0);
    mapper.set_chr_bank(0);
    mapper.set_nt_bank(0);
    // Light the green LED on the cartridge PCB.
    _ = mapper.set_mapper_green_led(true);
    const bg_pal: [16]u8 = .{ 0x19, 0x19, 0x29, 0x39 } ++ .{0x00} ** 12;
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
