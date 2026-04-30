// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! SNES π demo — port of pi_snes by Sirmacho.
//! https://x.com/RheoGamer/status/2049557714280288568
//! Computes ~900 digits of π using the Rabinowitz-Wagon Spigot algorithm
//! and displays them on BG1 using the pvsneslib font (pvsneslibfont.pic).
//!
//! VRAM layout (word addresses):
//!   $2000 : BG1 chr base  (BG12NBA = 0x02, unit = 0x1000 words)
//!   $3000 : font tiles    ($100 tiles × 16 words/tile = $2000 + $1000)
//!   $6800 : BG1 tilemap   (BG1SC = 0x68, 32×32 entries)
//!
//! Font: pvsneslibfont.pic — 96 SNES 4bpp tiles covering ASCII $20–$7F.
//! Tile index for character C = TILE_OFFSET + (C - 0x20).

const hw = @import("snes");
const sneslib = @import("sneslib");
comptime {
    _ = @import("snes_header");
}

const font_pic = @embedFile("pvsneslibfont.pic");

const CHR_BASE: u16 = 0x2000;
const FONT_VRAM: u16 = 0x3000;
const MAP_VRAM: u16 = 0x6800;
const TILE_OFFSET: u16 = 0x0100;
const MAP_COLS: u8 = 32;

const A_LEN: usize = 2687;

var A: [A_LEN]u8 = undefined;
var col: u8 = 0;
var row: u8 = 0;

fn draw_char(c: u8, r: u8, ch: u8) void {
    const idx: u16 = @as(u16, r) * MAP_COLS + c;
    const tile: u16 = TILE_OFFSET + (@as(u16, ch) - 0x20);
    // VRAM writes are only valid during force-blank or vblank.
    // Brief force-blank (<10 cycles) is imperceptible at ~60 fps.
    hw.INIDISP.* = 0x80;
    sneslib.vram_set_addr(MAP_VRAM + idx);
    sneslib.vram_write(@truncate(tile), @truncate(tile >> 8));
    hw.INIDISP.* = 0x0F;
}

fn print_digit(ch: u8) void {
    draw_char(col, row, ch);
    col +%= 1;
    if (col == MAP_COLS) {
        col = 0;
        row +%= 1;
    }
}

fn calculate_pi() void {
    hw.INIDISP.* = 0x80;
    sneslib.cgram_set(0, hw.color(31, 0, 0));
    hw.INIDISP.* = 0x0F;
    @memset(&A, 2);

    var nines: u8 = 0;
    var predigit: u32 = 0;

    var j: u16 = 1;
    while (j <= 896) : (j += 1) {
        var q: u32 = 0;
        var i: u32 = A_LEN;
        while (i > 0) : (i -= 1) {
            const k: u32 = 2 * i - 1;
            const idx: usize = @intCast(i - 1);
            const x: u32 = 10 * @as(u32, A[idx]) + q * i;
            q = x / k;
            A[idx] = @truncate(x % k);
        }
        const rem: u32 = q % 10;
        q = q / 10;
        A[0] = @truncate(rem);

        if (q == 9) {
            nines += 1;
        } else if (q == 10) {
            print_digit(@truncate(predigit + 1 + '0'));
            var n: u8 = 0;
            while (n < nines) : (n += 1) print_digit('0');
            predigit = 0;
            nines = 0;
        } else {
            print_digit(@truncate(predigit + '0'));
            predigit = q;
            if (nines != 0) {
                var n: u8 = 0;
                while (n < nines) : (n += 1) print_digit('9');
                nines = 0;
            }
        }
    }
    print_digit(@truncate(predigit + '0'));
}

pub fn main() void {
    sneslib.ppu_off();
    hw.VMAIN.* = 0x80; // increment VRAM address after VMDATAH write
    sneslib.bg_scroll_zero();

    // Clear BG1 tilemap (32×32 = 1024 entries)
    sneslib.vram_set_addr(MAP_VRAM);
    var m: u16 = 0;
    while (m < 1024) : (m += 1) sneslib.vram_write(0, 0);

    // Upload pvsneslibfont.pic tiles to VRAM word $3000
    sneslib.vram_set_addr(FONT_VRAM);
    var fi: usize = 0;
    while (fi < font_pic.len) : (fi += 2) {
        sneslib.vram_write(font_pic[fi], font_pic[fi + 1]);
    }

    var ci: u8 = 1;
    while (ci < 16) : (ci += 1) sneslib.cgram_set(ci, hw.color(31, 31, 31));

    // BG1: Mode 1 (4bpp), chr at $2000 words, map at $6800 words, 32×32
    hw.BGMODE.* = 0x01;
    hw.BG1SC.* = 0x68;
    hw.BG12NBA.* = 0x02;
    hw.TM.* = 0x01;

    sneslib.ppu_on();
    // Display shows black backdrop until calculate_pi() sets it to red.

    calculate_pi();

    // Green backdrop when done — use brief force-blank so CGRAM write is safe.
    hw.INIDISP.* = 0x80;
    sneslib.cgram_set(0, hw.color(0, 31, 0));
    hw.INIDISP.* = 0x0F;

    while (true) sneslib.wait_vblank();
}
