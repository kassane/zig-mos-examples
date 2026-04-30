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

pub const panic = @import("mos_panic");

const hw = @import("snes");
const sneslib = @import("sneslib");
comptime {
    _ = @import("snes_header");
}

const font_pic = @embedFile("pvsneslibfont.pic");

const FONT_VRAM: u16 = 0x3000;
const MAP_VRAM: u16 = 0x6800;
const TILE_OFFSET: u16 = 0x0100;
const MAP_COLS: u8 = 32;

const A_LEN: usize = 2687;
const MAX_DIGITS: usize = 900;

var A: [A_LEN]u8 = undefined;
// WRAM buffer: all computed digits as ASCII.
var pi_digits: [MAX_DIGITS]u8 = .{0} ** MAX_DIGITS;
var pi_count: u16 = 0;
// Tracks how many digits have been written to VRAM so far.
var render_head: u16 = 0;

fn store_digit(ch: u8) void {
    @setRuntimeSafety(false);
    if (pi_count < MAX_DIGITS) {
        pi_digits[pi_count] = ch;
        pi_count += 1;
    }
}

// Waits for the next VBlank then writes any digits not yet in VRAM.
// Called once per Spigot outer iteration — typically flushes 0–4 new tiles.
// VRAM writes during VBlank require no force-blank.
fn flush_new_vblank() void {
    @setRuntimeSafety(false);
    if (render_head >= pi_count) return;
    sneslib.wait_vblank();
    while (render_head < pi_count) {
        const tile: u16 = TILE_OFFSET + (@as(u16, pi_digits[render_head]) - 0x20);
        sneslib.vram_set_addr(MAP_VRAM + render_head);
        sneslib.vram_write(@truncate(tile), @truncate(tile >> 8));
        render_head += 1;
    }
}

fn calculate_pi() void {
    @setRuntimeSafety(false);
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
            store_digit(@truncate(predigit + 1 + '0'));
            var n: u8 = 0;
            while (n < nines) : (n += 1) store_digit('0');
            predigit = 0;
            nines = 0;
        } else {
            store_digit(@truncate(predigit + '0'));
            predigit = q;
            if (nines != 0) {
                var n: u8 = 0;
                while (n < nines) : (n += 1) store_digit('9');
                nines = 0;
            }
        }

        // Flush any new digits to VRAM during the upcoming VBlank.
        // Skipped when q==9 (no new digit this iteration).
        flush_new_vblank();
    }
    store_digit(@truncate(predigit + '0'));
    flush_new_vblank();
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

    calculate_pi();

    // Green backdrop when done — use brief force-blank so CGRAM write is safe.
    hw.INIDISP.* = 0x80;
    sneslib.cgram_set(0, hw.color(0, 31, 0));
    hw.INIDISP.* = 0x0F;

    while (true) sneslib.wait_vblank();
}
