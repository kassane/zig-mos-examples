// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES bat-and-ball demo: bat moves left/right with P1, ball bounces off walls.
//! Faithful Zig port of ProgrammingGamesForTheNES CH05 (originally 6502 assembly).
//! Sprites: tile 1 = bat, tile 2 = ball (example.chr bank 1).
pub const panic = @import("mos_panic");
const neslib = @import("neslib");

const TILE_BAT: u8 = 1;
const TILE_BALL: u8 = 2;

const palette_bg: [16]u8 = .{
    0x0f, 0x15, 0x26, 0x37, // bg0 purple/pink
    0x0f, 0x09, 0x19, 0x29, // bg1 green
    0x0f, 0x01, 0x11, 0x21, // bg2 blue
    0x0f, 0x00, 0x10, 0x30, // bg3 greyscale
};
const palette_sp: [16]u8 = .{
    0x0f, 0x18, 0x28, 0x38, // sp0 yellow
    0x0f, 0x14, 0x24, 0x34, // sp1 purple
    0x0f, 0x1b, 0x2b, 0x3b, // sp2 teal
    0x0f, 0x12, 0x22, 0x32, // sp3 marine
};

pub export fn main() callconv(.c) void {
    @setRuntimeSafety(false);
    neslib.ppu_off();
    neslib.pal_bg(&palette_bg);
    neslib.pal_spr(&palette_sp);
    neslib.bank_spr(1);

    neslib.vram_adr(neslib.NTADR_A(10, 4));
    neslib.vram_write("WELCOME", 7);

    neslib.ppu_on_all();

    var bat_x: u8 = 120;
    const bat_y: u8 = 180;
    var ball_x: u8 = 124;
    var ball_y: u8 = 124;
    var d_x: u8 = 1;
    var d_y: u8 = 1;

    while (true) {
        neslib.ppu_wait_nmi();

        const pad = neslib.pad_poll(0);

        if (pad & 0x02 != 0 and bat_x > 0) bat_x -= 1; // PAD_LEFT
        if (pad & 0x01 != 0 and bat_x < 248) bat_x += 1; // PAD_RIGHT

        ball_y = ball_y +% d_y;
        if (ball_y == 0) d_y = 1;
        if (ball_y == 210) d_y = 0xFF; // -1 wrapping

        ball_x = ball_x +% d_x;
        if (ball_x == 0) d_x = 1;
        if (ball_x == 248) d_x = 0xFF; // -1 wrapping

        neslib.oam_clear();
        neslib.oam_spr(bat_x, bat_y, TILE_BAT, 0);
        neslib.oam_spr(ball_x, ball_y, TILE_BALL, 0);
    }
}
