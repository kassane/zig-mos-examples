// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0

pub const panic = @import("mos_panic");

const hw = @import("snes");
const sneslib = @import("sneslib");

comptime {
    _ = @import("snes_header");
}

// Held together resets to the first color — demonstrates buttonMask().
const RESET_COMBO = sneslib.buttonMask(.{ sneslib.KEY_A, sneslib.KEY_B });

// pvsneslibfont.pic: 96 SNES 4bpp tiles covering ASCII $20–$7F.
const font_pic = @embedFile("pvsneslibfont.pic");

const FONT_VRAM: u16 = 0x3000; // chr base word addr (BG12NBA=0x02 → $2000; font offset $1000 → $3000)
const MAP_VRAM: u16 = 0x6800; // BG1 tilemap word addr (BG1SC=0x68)
const TILE_OFFSET: u16 = 0x0100; // tile index of ASCII $20 in the font
const MAP_COLS: u16 = 32;

// Palette 0 (CGRAM 0-15) : dim white — normal text.
// Palette 1 (CGRAM 16-31): bright yellow — active/held button highlight.
const PAL_NORMAL: u16 = 0;
const PAL_ACTIVE: u16 = 1;

const COLORS = [16]u16{
    hw.color(31, 0, 0), // red
    hw.color(31, 16, 0), // orange
    hw.color(31, 31, 0), // yellow
    hw.color(0, 31, 0), // green
    hw.color(0, 31, 31), // cyan
    hw.color(0, 0, 31), // blue
    hw.color(16, 0, 31), // violet
    hw.color(31, 0, 31), // magenta
    hw.color(31, 31, 31), // white
    hw.color(20, 20, 20), // light gray
    hw.color(10, 10, 10), // dark gray
    hw.color(31, 10, 10), // pink
    hw.color(10, 31, 10), // mint
    hw.color(10, 10, 31), // light blue
    hw.color(31, 20, 0), // gold
    hw.color(0, 20, 31), // sky blue
};

// Write a string to the BG1 tilemap. VMAIN must be 0x80 (auto-increment).
fn put_str(row: u8, col: u8, str: []const u8, pal: u16) void {
    sneslib.vram_set_addr(MAP_VRAM + @as(u16, row) * MAP_COLS + col);
    for (str) |ch| {
        const t: u16 = TILE_OFFSET + @as(u16, ch - 0x20);
        const entry: u16 = t | (pal << 10);
        sneslib.vram_write(@truncate(entry), @truncate(entry >> 8));
    }
}

pub fn main() void {
    sneslib.ppu_off();
    hw.VMAIN.* = 0x80; // auto-increment VRAM word address after VMDATAH write

    sneslib.bg_scroll_zero();

    // Clear BG1 tilemap (32×32 entries)
    sneslib.vram_set_addr(MAP_VRAM);
    var m: u16 = 0;
    while (m < 1024) : (m += 1) sneslib.vram_write(0, 0);

    // Upload pvsneslibfont.pic to VRAM at FONT_VRAM
    sneslib.vram_set_addr(FONT_VRAM);
    var fi: usize = 0;
    while (fi < font_pic.len) : (fi += 2) {
        sneslib.vram_write(font_pic[fi], font_pic[fi + 1]);
    }

    // Palette 0 colors 1-15: dim white (normal text)
    var ci: u8 = 1;
    while (ci < 16) : (ci += 1) sneslib.cgram_set(ci, hw.color(24, 24, 24));
    // Palette 1 colors 17-31: bright yellow (active button highlight)
    ci = 17;
    while (ci < 32) : (ci += 1) sneslib.cgram_set(ci, hw.color(31, 28, 0));

    // BG1: Mode 1 (4bpp), chr at $2000 words, map at $6800 words
    hw.BGMODE.* = 0x01;
    hw.BG1SC.* = 0x68;
    hw.BG12NBA.* = 0x02;
    hw.TM.* = 0x01;

    // Static labels (written once during force-blank)
    put_str(5, 9, "SNES PADS DEMO", PAL_NORMAL);
    put_str(11, 6, "CYCLES BACKDROP", PAL_NORMAL);
    put_str(15, 10, " = RESET", PAL_NORMAL);

    // Initial backdrop color
    sneslib.cgram_set(0, COLORS[0]);

    sneslib.ppu_on();

    var idx: u8 = 0;

    while (true) {
        sneslib.wait_vblank();

        // Update backdrop color — safe inside VBlank window
        sneslib.cgram_set(0, COLORS[idx]);

        // Dynamic button indicators: bright yellow when held, dim when released
        put_str(9, 2, "< LEFT ", if (sneslib.held(0, sneslib.KEY_LEFT)) PAL_ACTIVE else PAL_NORMAL);
        put_str(9, 22, " RIGHT >", if (sneslib.held(0, sneslib.KEY_RIGHT)) PAL_ACTIVE else PAL_NORMAL);
        put_str(15, 5, "A + B", if (sneslib.held(0, RESET_COMBO)) PAL_ACTIVE else PAL_NORMAL);

        // LEFT/RIGHT cycle the backdrop color (single-frame press → one step)
        if (sneslib.pressed(0, sneslib.KEY_RIGHT)) {
            idx = (idx + 1) % @as(u8, COLORS.len);
        }
        if (sneslib.pressed(0, sneslib.KEY_LEFT)) {
            idx = if (idx == 0) @as(u8, COLORS.len - 1) else idx - 1;
        }
        // A+B held resets to the first color
        if (sneslib.held(0, RESET_COMBO)) {
            idx = 0;
        }
    }
}
