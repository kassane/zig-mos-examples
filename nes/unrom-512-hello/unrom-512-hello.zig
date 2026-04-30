// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES UNROM-512 mapper hello — solid background colour, explicit PRG bank init.
//! UNROM-512 (mapper 30) switches 32 x 16 KiB PRG ROM banks at $8000-$BFFF by
//! writing to $8000-$FFFF.  Uses 32 KiB CHR RAM (no CHR ROM embedded).
//! Uses translated mapper.h (set_prg_bank / get_prg_bank / set_chr_bank /
//! banked_call).
pub const panic = @import("mos_panic");
const neslib = @import("neslib");
const mapper = @import("mapper");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    // Switch to PRG bank 0 explicitly before enabling rendering.
    _ = mapper.set_prg_bank(0);
    // CHR bank 0 is already selected at reset; explicit for clarity.
    mapper.set_chr_bank(0);
    const bg_pal: [16]u8 = .{ 0x1A, 0x1A, 0x27, 0x30 } ++ .{0x00} ** 12;
    neslib.pal_bright(4);
    neslib.pal_bg(&bg_pal);
    neslib.ppu_on_all();
    while (true) {
        neslib.ppu_wait_nmi();
    }
}
