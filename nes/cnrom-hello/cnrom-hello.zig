// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES CNROM mapper hello — solid background colour, explicit CHR bank init.
//! CNROM (mapper 3) switches 8 KiB CHR ROM banks by writing to $8000-$FFFF.
//! Uses translated mapper.h (set_chr_bank / swap_chr_bank / split_chr_bank).
pub const panic = @import("mos_panic");
const neslib = @import("neslib");
const mapper = @import("mapper");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    // Select CHR bank 0 (Alpha.chr) before enabling rendering.
    mapper.set_chr_bank(0);
    // Blue background: NES palette 0x11 (light blue), white text on colour 3.
    const bg_pal: [16]u8 = .{ 0x11, 0x00, 0x10, 0x30 } ++ .{0x00} ** 12;
    neslib.pal_bright(4);
    neslib.pal_bg(&bg_pal);
    neslib.vram_adr(neslib.NTADR_A(4, 14));
    for ("CNROM Hello!") |c| neslib.vram_put(c);
    neslib.ppu_on_all();
    while (true) {
        neslib.ppu_wait_nmi();
    }
}
