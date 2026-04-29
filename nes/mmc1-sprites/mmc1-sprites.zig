// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES MMC1 sprites demo: uploads Alpha2.chr into CHR RAM at startup, then
//! draws scrolling sprites.  MMC1 (mapper 1) uses CHR RAM; tile data must be
//! written to PPU $0000–$1FFF while rendering is off.
//! Matches nesdoug 07_Sprites ported to MMC1.
const neslib = @import("neslib");
const mapper = @import("mapper");

const palette_bg: [16]u8 = .{ 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30 };
const palette_sp: [16]u8 = .{ 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28 };

const chr_data = @embedFile("Alpha2.chr");

// Each metasprite entry: x_off, y_off, tile, attr; terminated by 128.
const metasprite: []const u8 = &.{
    0, 0, 0x01, 0x00,
    0, 8, 0x11, 0x00,
    8, 0, 0x01, 0x40, // OAM_FLIP_H
    8,   8, 0x11, 0x40, // OAM_FLIP_H
    128,
};

const metasprite2: []const u8 = &.{
    8, 0, 0x03, 0x00,
    0, 8, 0x12, 0x00,
    8, 8, 0x13, 0x00,
    16, 8,  0x12, 0x40, // OAM_FLIP_H
    0,  16, 0x22, 0x00,
    8,  16, 0x23, 0x00,
    16,  16, 0x22, 0x40, // OAM_FLIP_H
    128,
};

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    // 0x0E = bit4=0 (8KB CHR mode), bits2-3=11 (fix last PRG bank), bits0-1=10 (vertical mirror).
    // Must set 8KB CHR mode before uploading; default 0x1F has bit4=1 (4KB mode) which aliases
    // both PPU halves to the same 4KB, causing the second 4KB write to overwrite the first.
    mapper.set_mmc1_ctrl(0x0E);
    mapper.set_prg_bank(0);
    // Upload 8 KiB of CHR tile data to PPU pattern tables while rendering is off.
    neslib.vram_adr(0x0000);
    neslib.vram_write(chr_data, @intCast(chr_data.len));
    neslib.pal_bright(4);
    neslib.pal_bg(&palette_bg);
    neslib.pal_spr(&palette_sp);
    neslib.bank_spr(1);
    neslib.vram_adr(neslib.NTADR_A(5, 14));
    neslib.vram_write("MMC1 Sprites", 12);
    neslib.ppu_on_all();

    var y_pos: u8 = 0x40;
    const x_pos: u8 = 0x88;
    const x_pos2: u8 = 0xa0;
    const x_pos3: u8 = 0xc0;

    while (true) {
        neslib.ppu_wait_nmi();
        neslib.oam_clear();
        neslib.oam_spr(x_pos, y_pos, 0, 0);
        neslib.oam_meta_spr(x_pos2, y_pos, @ptrCast(metasprite.ptr));
        neslib.oam_meta_spr(x_pos3, y_pos, @ptrCast(metasprite2.ptr));
        y_pos +%= 1;
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
