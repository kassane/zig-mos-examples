// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES Megablast: title screen + game screen.
//! Faithful Zig port of ProgrammingGamesForTheNES CH06 (originally 6502 assembly).
//! NROM, BG at $0000, OBJ at $1000.
const neslib = @import("neslib");

const NAMETABLE_A: u16 = 0x2000;
const ATTRIBUTE_TABLE_0: u16 = 0x23C0;

// PAD button masks (NES standard)
const PAD_A: u8 = 0x80;
const PAD_B: u8 = 0x40;
const PAD_SELECT: u8 = 0x20;
const PAD_START: u8 = 0x10;

const palette_bg: [16]u8 = .{
    0x0F, 0x15, 0x26, 0x37, // bg0 purple/pink
    0x0F, 0x19, 0x29, 0x39, // bg1 green
    0x0F, 0x11, 0x21, 0x31, // bg2 blue
    0x0F, 0x00, 0x10, 0x30, // bg3 greyscale
};
const palette_sp: [16]u8 = .{
    0x0F, 0x28, 0x21, 0x11, // sp0 player
    0x0F, 0x14, 0x24, 0x34, // sp1 purple
    0x0F, 0x1B, 0x2B, 0x3B, // sp2 teal
    0x0F, 0x12, 0x22, 0x32, // sp3 marine
};

const title_text = "M E G A  B L A S T";
const press_fire_text = "PRESS FIRE TO BEGIN";
const title_attributes: [8]u8 = .{0x05} ** 8;

const mountain_tiles: [32]u8 = .{ 1, 2, 3, 4 } ** 8;
const score_text = "SCORE 000000";

fn displayTitleScreen() void {
    neslib.ppu_off();
    neslib.oam_clear();
    // Clear nametable (32×32 tiles = 1024 bytes)
    neslib.vram_adr(NAMETABLE_A);
    neslib.vram_fill(0, 1024);

    neslib.vram_adr(neslib.NTADR_A(6, 4));
    neslib.vram_write(title_text, title_text.len);

    neslib.vram_adr(neslib.NTADR_A(6, 20));
    neslib.vram_write(press_fire_text, press_fire_text.len);

    // Set attribute bytes for title text (row 1 of attribute table = offset 8)
    neslib.vram_adr(ATTRIBUTE_TABLE_0 + 8);
    neslib.vram_write(&title_attributes, 8);

    neslib.ppu_on_all();
}

fn displayGameScreen() void {
    neslib.ppu_off();
    neslib.oam_clear();
    // Clear nametable
    neslib.vram_adr(NAMETABLE_A);
    neslib.vram_fill(0, 1024);

    // Mountain tiles at row 22
    neslib.vram_adr(neslib.NTADR_A(0, 22));
    neslib.vram_write(&mountain_tiles, 32);

    // Baseline: tile 9 repeated 32 times at row 26
    neslib.vram_adr(neslib.NTADR_A(0, 26));
    neslib.vram_fill(9, 32);

    // Score text at row 27
    neslib.vram_adr(neslib.NTADR_A(0, 27));
    neslib.vram_write(score_text, score_text.len);

    neslib.ppu_on_all();
}

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bg(&palette_bg);
    neslib.pal_spr(&palette_sp);
    neslib.bank_spr(1);

    displayTitleScreen();

    // Wait for any button press to start game
    while (true) {
        neslib.ppu_wait_nmi();
        const pad = neslib.pad_poll(0);
        if (pad & (PAD_A | PAD_B | PAD_START | PAD_SELECT) != 0) break;
    }

    displayGameScreen();

    // Main game loop (no game logic yet in CH06)
    while (true) {
        neslib.ppu_wait_nmi();
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
