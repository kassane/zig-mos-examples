// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES sprites demo: draws a single sprite and two metasprites, scrolling down.
//! Matches nesdoug 07_Sprites: bank_spr(1) routes sprites to the upper CHR bank.
const neslib = @import("neslib");

const palette_bg: [16]u8 = .{ 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30 };
const palette_sp: [16]u8 = .{ 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28 };

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
    neslib.pal_bg(&palette_bg);
    neslib.pal_spr(&palette_sp);
    // Route sprites to pattern table 1 (upper 4KB of Alpha2.chr).
    neslib.bank_spr(1);
    neslib.vram_adr(neslib.NTADR_A(7, 14));
    neslib.vram_write("Sprites", 7);
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
