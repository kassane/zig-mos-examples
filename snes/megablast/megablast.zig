// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! SNES Megablast: port of the NES CH13 full game to SNES.
//! Mode 1 (BG1 4bpp + OBJ 4bpp). CHR from nesdoug/megablast/megablast.chr.

pub const panic = @import("mos_panic");

const hw = @import("snes");
const sneslib = @import("sneslib");
comptime {
    _ = @import("snes_header");
}

// ── Comptime CHR conversion ───────────────────────────────────────────────────
// NES 2bpp tile: bytes 0-7 = plane 0 (one byte per row), bytes 8-15 = plane 1.
// SNES 4bpp tile: bytes 0-15 = planes 0+1 interleaved by row, bytes 16-31 = planes 2+3 (zero).

const nes_chr_raw = @embedFile("megablast.chr");

const snes_chr_bg: [256 * 32]u8 = blk: {
    @setEvalBranchQuota(20000);
    var out: [256 * 32]u8 = .{0} ** (256 * 32);
    for (0..256) |t| {
        const src = t * 16;
        const dst = t * 32;
        for (0..8) |row| {
            out[dst + row * 2 + 0] = nes_chr_raw[src + row]; // plane 0
            out[dst + row * 2 + 1] = nes_chr_raw[src + 8 + row]; // plane 1
        }
        // bytes 16-31: planes 2+3 stay zero (4-color subset of 4bpp)
    }
    break :blk out;
};

const snes_chr_spr: [256 * 32]u8 = blk: {
    @setEvalBranchQuota(20000);
    var out: [256 * 32]u8 = .{0} ** (256 * 32);
    for (0..256) |t| {
        const src = (256 + t) * 16; // NES bank 1 (sprite CHR)
        const dst = t * 32;
        for (0..8) |row| {
            out[dst + row * 2 + 0] = nes_chr_raw[src + row];
            out[dst + row * 2 + 1] = nes_chr_raw[src + 8 + row];
        }
    }
    break :blk out;
};

// ── NES → SNES colour lookup (runtime-safe, constants fold to immediates) ────

fn nesColor(n: u8) u16 {
    return switch (n) {
        0x00 => sneslib.color(10, 10, 10),
        0x0F => sneslib.color(0, 0, 0),
        0x10 => sneslib.color(15, 15, 15),
        0x11 => sneslib.color(0, 15, 28),
        0x12 => sneslib.color(5, 5, 28),
        0x15 => sneslib.color(25, 5, 5),
        0x17 => sneslib.color(28, 14, 5),
        0x18 => sneslib.color(20, 25, 3),
        0x19 => sneslib.color(3, 20, 5),
        0x21 => sneslib.color(5, 28, 28),
        0x22 => sneslib.color(8, 20, 28),
        0x26 => sneslib.color(25, 3, 25),
        0x27 => sneslib.color(28, 8, 25),
        0x28 => sneslib.color(20, 28, 5),
        0x29 => sneslib.color(3, 28, 15),
        0x30 => sneslib.color(25, 25, 25),
        0x31 => sneslib.color(18, 20, 31),
        0x32 => sneslib.color(10, 10, 31),
        0x37 => sneslib.color(12, 28, 28),
        0x38 => sneslib.color(28, 28, 2),
        0x39 => sneslib.color(31, 31, 2),
        else => sneslib.color(0, 0, 0),
    };
}

// ── Constants ──────────────────────────────────────────────────────────────────

// NES palette data (used only for comptime colour conversion)
const bg_palette: [16]u8 = .{
    0x0F, 0x15, 0x26, 0x37,
    0x0F, 0x19, 0x29, 0x39,
    0x0F, 0x11, 0x21, 0x31,
    0x0F, 0x00, 0x10, 0x30,
};
const sp_palette: [16]u8 = .{
    0x0F, 0x28, 0x21, 0x11, // OBJ pal 0 (attr=0) player
    0x0F, 0x26, 0x28, 0x17, // OBJ pal 1 (attr=1) small meteor
    0x0F, 0x38, 0x28, 0x18, // OBJ pal 2 (attr=2) large meteor
    0x0F, 0x12, 0x22, 0x32, // OBJ pal 3 (attr=3) smart bomb
};

const mountain_tiles: [32]u8 = .{ 1, 2, 3, 4 } ** 8;

const ENEMY_SRC: [3][9]u8 = .{
    .{ 8, 12, 4, 0, 2, 2, 12, 12, 2 }, // large meteor
    .{ 36, 37, 1, 1, 3, 3, 8, 7, 2 }, // small meteor
    .{ 16, 19, 1, 2, 3, 6, 8, 8, 3 }, // smart bomb
};

// ── OAM buffers ───────────────────────────────────────────────────────────────
// Game logic uses NES OAM layout [Y, tile, attr, X] × 64 sprites.
// Before each VBlank DMA we convert to SNES layout.

var nes_oam: [256]u8 = .{0xFF} ** 256;
var snes_oam: [544]u8 = .{0} ** 544; // 512 table1 + 32 table2

fn convertAttr(nes_attr: u8) u8 {
    // NES attr: bit7=vflip, bit6=hflip, bits1-0=palette
    // SNES attr: bit7=vflip, bit6=xflip, bits4-2=palette, bit5=priority(1=above BG)
    const vflip: u8 = nes_attr & 0x80; // keep bit7 in place
    const hflip: u8 = nes_attr & 0x40; // keep bit6 in place
    const pal: u8 = (nes_attr & 0x03) << 2;
    return vflip | hflip | pal | 0x20;
}

fn convertOam() void {
    @setRuntimeSafety(false);
    for (0..64) |i| {
        const nes_y = nes_oam[i * 4 + 0];
        const tile = nes_oam[i * 4 + 1];
        const attr = nes_oam[i * 4 + 2];
        const x = nes_oam[i * 4 + 3];
        // SNES OAM table1: [X_lo, Y, tile, attr]
        // NES Y is "scanline before sprite", SNES Y is direct → add 1
        snes_oam[i * 4 + 0] = x;
        snes_oam[i * 4 + 1] = if (nes_y >= 0xFE) 0xFF else nes_y +% 1;
        snes_oam[i * 4 + 2] = tile;
        snes_oam[i * 4 + 3] = convertAttr(attr);
    }
    // Hide sprites 64–127 (SNES supports 128; NES only uses 64)
    for (64..128) |i| {
        snes_oam[i * 4 + 1] = 0xFF; // Y = off-screen
    }
    // Table2: all sprites small (8×8), X <= 255 so high bit = 0
    @memset(snes_oam[512..], 0);
}

// ── Game state ────────────────────────────────────────────────────────────────

var level: u8 = 1;
var score: [3]u8 = .{ 0, 0, 0 };
var highscore: [3]u8 = .{ 0, 1, 0 };
var lives: u8 = 5;
var player_dead: u8 = 0;
var flash: u8 = 0;
var shake: u8 = 0;
var enemy_cooldown: u8 = 0;
var enemy_count: u8 = 0;
var display_level: u8 = 0;
var enemy_data: [100]u8 = .{0} ** 100;
var star_addrs: [10]u16 = .{0} ** 10;
var pal1: u8 = bg_palette[1];
var pal2: u8 = bg_palette[2];
var score_dirty: bool = false;
var highscore_dirty: bool = false;
var lives_dirty: bool = false;
var level_dirty: bool = false;
var level_erase_dirty: bool = false;
var gameover_dirty: bool = false;
var frame_count: u8 = 0;
var rng_state: u16 = 0x1234;

// ── RNG (16-bit Galois LFSR) ──────────────────────────────────────────────────

fn rand8() u8 {
    @setRuntimeSafety(false);
    rng_state ^= rng_state << 7;
    rng_state ^= rng_state >> 9;
    rng_state ^= rng_state << 8;
    return @truncate(rng_state);
}

// ── VRAM tilemap helpers ──────────────────────────────────────────────────────
// SNES tilemap word: bits 9-0 = tile index, bits 12-10 = palette, bit 5 = priority.
// For palette 0, no flip: high byte = 0x00.

fn tmaddr(row: u8, col: u8) u16 {
    return @as(u16, row) * 32 + col;
}

fn vramWriteRow(row: u8, col: u8, tiles: []const u8) void {
    sneslib.vram_set_addr(tmaddr(row, col));
    for (tiles) |t| sneslib.vram_write(t, 0x00);
}

fn vramFillRow(row: u8, col: u8, tile: u8, count: u8) void {
    sneslib.vram_set_addr(tmaddr(row, col));
    var i: u8 = 0;
    while (i < count) : (i += 1) sneslib.vram_write(tile, 0x00);
}

fn dec2(val: u8, out: *[2]u8) void {
    out[0] = val / 10 + '0';
    out[1] = val % 10 + '0';
}

// ── HUD VRAM writes (call from VBlank window after wait_vblank) ───────────────
// SNES rows adjusted for 224-line screen (NES had 240):
//   row 1:  high score    row 13: level text
//   row 22: mountain      row 25: score + lives row A
//   row 26: ground + lives row B

fn writeScore() void {
    var buf: [7]u8 = undefined;
    var d: [2]u8 = undefined;
    dec2(score[2], &d);
    buf[0] = d[0];
    buf[1] = d[1];
    dec2(score[1], &d);
    buf[2] = d[0];
    buf[3] = d[1];
    dec2(score[0], &d);
    buf[4] = d[0];
    buf[5] = d[1];
    buf[6] = '0';
    vramWriteRow(25, 6, &buf);
}

fn writeHighScore() void {
    var buf: [7]u8 = undefined;
    var d: [2]u8 = undefined;
    dec2(highscore[2], &d);
    buf[0] = d[0];
    buf[1] = d[1];
    dec2(highscore[1], &d);
    buf[2] = d[0];
    buf[3] = d[1];
    dec2(highscore[0], &d);
    buf[4] = d[0];
    buf[5] = d[1];
    buf[6] = '0';
    vramWriteRow(1, 13, &buf);
}

fn writeLives() void {
    var row1: [16]u8 = .{0} ** 16;
    var row2: [16]u8 = .{0} ** 16;
    const n: u8 = if (lives > 8) 8 else lives;
    var i: u8 = 0;
    while (i < n) : (i += 1) {
        row1[i * 2] = 5;
        row1[i * 2 + 1] = 6;
        row2[i * 2] = 7;
        row2[i * 2 + 1] = 8;
    }
    vramWriteRow(25, 14, &row1);
    vramWriteRow(26, 14, &row2);
}

fn writeLevelText() void {
    var buf: [14]u8 = " L E V E L    ".*;
    var d: [2]u8 = undefined;
    dec2(level, &d);
    buf[12] = d[0];
    buf[13] = d[1];
    vramWriteRow(13, 9, &buf);
}

fn writeLevelErase() void {
    const blank: [14]u8 = .{0} ** 14;
    vramWriteRow(13, 9, &blank);
}

fn writeGameOver() void {
    const text = " G A M E  O V E R";
    vramWriteRow(13, 7, text);
}

// ── Game logic (ported from NES megablast, oam → nes_oam) ────────────────────

fn addScore(pts: u8) void {
    @setRuntimeSafety(false);
    const s0 = @as(u16, score[0]) + pts;
    if (s0 >= 100) {
        score[0] = @intCast(s0 - 100);
        const s1 = @as(u16, score[1]) + 1;
        if (s1 >= 100) {
            score[1] = @intCast(s1 - 100);
            const s2 = @as(u16, score[2]) + 1;
            score[2] = @intCast(if (s2 >= 100) s2 - 100 else s2);
        } else {
            score[1] = @intCast(s1);
        }
    } else {
        score[0] = @intCast(s0);
    }
    score_dirty = true;
    if (score[2] > highscore[2] or
        (score[2] == highscore[2] and score[1] > highscore[1]) or
        (score[2] == highscore[2] and score[1] == highscore[1] and score[0] > highscore[0]))
    {
        highscore = score;
        highscore_dirty = true;
    }
}

fn subtractScore(pts: u8) void {
    @setRuntimeSafety(false);
    if (score[0] == 0 and score[1] == 0 and score[2] == 0) return;
    if (score[0] >= pts) {
        score[0] -= pts;
    } else {
        const need = pts - score[0];
        score[0] = 100 - need;
        if (score[1] > 0) {
            score[1] -= 1;
        } else {
            score[1] = 99;
            score[2] = if (score[2] > 0) score[2] - 1 else 0;
        }
    }
    score_dirty = true;
}

fn placeStars() void {
    for (&star_addrs) |*a| {
        const r = rand8();
        const row: u8 = (r & 0x0F) + 3;
        const col: u8 = r >> 4;
        const addr = tmaddr(row, col);
        a.* = addr;
        sneslib.vram_set_addr(addr);
        sneslib.vram_write(0x0c, 0x00);
    }
}

fn animateStars() void {
    @setRuntimeSafety(false);
    if (frame_count & 3 != 0) return;
    const tile: u8 = if ((frame_count >> 2) & 1 != 0) 13 else 12;
    for (star_addrs) |a| {
        if (a == 0) continue;
        sneslib.vram_set_addr(a);
        sneslib.vram_write(tile, 0x00);
    }
}

fn setupLevel() void {
    @memset(&enemy_data, 0);
    enemy_cooldown = 20;
    enemy_count = 0;
    display_level = 64;
    level_dirty = true;
    var i: usize = 20;
    while (i < 180) : (i += 1) nes_oam[i] = 0xFF;
    nes_oam[16] = 0xFF;
}

fn displayPlayer() void {
    nes_oam[0] = 196;
    nes_oam[4] = 196;
    nes_oam[8] = 204;
    nes_oam[12] = 204;
    nes_oam[1] = 0;
    nes_oam[5] = 1;
    nes_oam[9] = 2;
    nes_oam[13] = 3;
    nes_oam[2] = 0;
    nes_oam[6] = 0;
    nes_oam[10] = 0;
    nes_oam[14] = 0;
    nes_oam[3] = 120;
    nes_oam[11] = 120;
    nes_oam[7] = 128;
    nes_oam[15] = 128;
}

fn setPlayerShape(pat: u8) void {
    nes_oam[1] = pat;
    nes_oam[5] = pat + 1;
    nes_oam[9] = pat + 2;
    nes_oam[13] = pat + 3;
}

fn spawnEnemy() void {
    @setRuntimeSafety(false);
    if (enemy_cooldown > 0) {
        enemy_cooldown -= 1;
        if (enemy_cooldown != 0) return;
    }
    enemy_cooldown = 1;
    const thresh = (@as(u16, level) + 1) * 4;
    const rnd = rand8();
    if (rnd >= @as(u8, @truncate(if (thresh > 255) 255 else thresh))) return;
    enemy_cooldown = 20;
    var slot: u8 = 255;
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        if (enemy_data[@as(usize, i) * 10] == 0) {
            slot = i;
            break;
        }
    }
    if (slot == 255) return;
    enemy_count +%= 1;
    if (enemy_count >= 40) {
        level += 1;
        enemy_count = 0;
        display_level = 64;
        level_dirty = true;
    }
    const rnd2 = rand8();
    const etype: u8 = if (rnd2 & 0x0F == 0x0F) 3 else (rnd2 & 1) + 1;
    const base = @as(usize, slot) * 10;
    enemy_data[base] = etype;
    @memcpy(enemy_data[base + 1 .. base + 10], &ENEMY_SRC[etype - 1]);
    if (enemy_data[base + 4] != 0 and rand8() & 1 != 0)
        enemy_data[base + 4] = (~enemy_data[base + 4]) +% 1;
    const ob: usize = @as(usize, slot) * 16 + 20;
    const one_spr = enemy_data[base + 3] == 1;
    const sp = enemy_data[base + 1];
    const attr = enemy_data[base + 9];
    if (one_spr) {
        const xpos: u8 = (rand8() & 0x70) + 48;
        nes_oam[ob + 0] = 0;
        nes_oam[ob + 4] = 0xFF;
        nes_oam[ob + 8] = 0xFF;
        nes_oam[ob + 12] = 0xFF;
        nes_oam[ob + 1] = sp;
        nes_oam[ob + 2] = attr;
        nes_oam[ob + 3] = xpos;
    } else {
        const xpos: u8 = (rand8() & 0xF0) + 48;
        nes_oam[ob + 0] = 0;
        nes_oam[ob + 4] = 0;
        nes_oam[ob + 8] = 8;
        nes_oam[ob + 12] = 8;
        nes_oam[ob + 1] = sp;
        nes_oam[ob + 5] = sp + 1;
        nes_oam[ob + 9] = sp + 2;
        nes_oam[ob + 13] = sp + 3;
        nes_oam[ob + 2] = attr;
        nes_oam[ob + 6] = attr;
        nes_oam[ob + 10] = attr;
        nes_oam[ob + 14] = attr;
        nes_oam[ob + 3] = xpos;
        nes_oam[ob + 11] = xpos;
        nes_oam[ob + 7] = xpos +% 8;
        nes_oam[ob + 15] = xpos +% 8;
    }
}

fn moveEnemies() void {
    @setRuntimeSafety(false);
    const bx = nes_oam[19];
    const by = nes_oam[16];
    const bullet_on = by != 0xFF;
    var slot: u8 = 0;
    while (slot < 10) : (slot += 1) {
        const base = @as(usize, slot) * 10;
        if (enemy_data[base] == 0) continue;
        const ob: usize = @as(usize, slot) * 16 + 20;
        const dy = enemy_data[base + 5];
        const ht = enemy_data[base + 8];
        const wd = enemy_data[base + 7];
        const one_spr = enemy_data[base + 3] == 1;
        if (enemy_data[base] == 3) {
            const sx = nes_oam[ob + 3];
            const px = nes_oam[3];
            const sdx = enemy_data[base + 4];
            if (sdx & 0x80 != 0) {
                if (px >= sx and px - sx >= 32)
                    enemy_data[base + 4] = (~sdx) +% 1;
            } else {
                if (sx >= px and sx - px >= 44)
                    enemy_data[base + 4] = (~sdx) +% 1;
            }
        }
        const dx = enemy_data[base + 4];
        if (dx != 0) {
            const nx = nes_oam[ob + 3] +% dx;
            nes_oam[ob + 3] = nx;
            nes_oam[ob + 11] = nx;
            nes_oam[ob + 7] = nx +% 8;
            nes_oam[ob + 15] = nx +% 8;
        }
        const ny = nes_oam[ob] +% dy;
        nes_oam[ob] = ny;
        if (@as(u16, ny) + ht >= 204) {
            nes_oam[ob + 0] = 0xFF;
            nes_oam[ob + 4] = 0xFF;
            nes_oam[ob + 8] = 0xFF;
            nes_oam[ob + 12] = 0xFF;
            if (enemy_data[base] == 3) {
                flash = 32;
                shake = 32;
            }
            enemy_data[base] = 0;
            subtractScore(1);
            continue;
        }
        if (!one_spr) {
            nes_oam[ob + 4] = ny;
            nes_oam[ob + 8] = ny +% 8;
            nes_oam[ob + 12] = ny +% 8;
        }
        if (frame_count & 3 == 0) {
            const sp_start = enemy_data[base + 1];
            const sp_end = enemy_data[base + 2];
            if (sp_start != sp_end) {
                if (one_spr) {
                    var p = nes_oam[ob + 1] + 1;
                    if (p >= sp_end) p = sp_start;
                    nes_oam[ob + 1] = p;
                } else {
                    var p = nes_oam[ob + 1] +% 4;
                    if (p >= sp_end) p = sp_start;
                    nes_oam[ob + 1] = p;
                    nes_oam[ob + 5] = p + 1;
                    nes_oam[ob + 9] = p + 2;
                    nes_oam[ob + 13] = p + 3;
                }
            }
        }
        if (player_dead == 0) {
            if (@as(u16, ny) + ht >= 0xC4) {
                const ex = nes_oam[ob + 3];
                const px = nes_oam[3];
                if (px +% 12 >= ex and ex +% wd >= px) {
                    if (lives > 0) lives -= 1;
                    lives_dirty = true;
                    player_dead = 1;
                    nes_oam[ob + 0] = 0xFF;
                    nes_oam[ob + 4] = 0xFF;
                    nes_oam[ob + 8] = 0xFF;
                    nes_oam[ob + 12] = 0xFF;
                    enemy_data[base] = 0;
                    continue;
                }
            }
        }
        if (bullet_on) {
            const ey = ny;
            const ex = nes_oam[ob + 3];
            if (by +% 4 >= ey and @as(u16, ey) + ht > by and
                bx >= ex and @as(u16, ex) + wd > bx)
            {
                nes_oam[16] = 0xFF;
                nes_oam[ob + 0] = 0xFF;
                nes_oam[ob + 4] = 0xFF;
                nes_oam[ob + 8] = 0xFF;
                nes_oam[ob + 12] = 0xFF;
                addScore(enemy_data[base + 6]);
                enemy_data[base] = 0;
            }
        }
    }
}

fn playerActions(pad: u16) void {
    @setRuntimeSafety(false);
    if (player_dead != 0) {
        switch (player_dead) {
            1 => {
                setPlayerShape(20);
                nes_oam[2] = 1;
                nes_oam[6] = 1;
                nes_oam[10] = 1;
                nes_oam[14] = 1;
            },
            5 => setPlayerShape(24),
            10 => setPlayerShape(28),
            15 => setPlayerShape(32),
            20 => {
                if (lives == 0) return;
                setupLevel();
                displayPlayer();
                player_dead = 0;
                lives_dirty = true;
                return;
            },
            else => {},
        }
        player_dead += 1;
        return;
    }
    if (pad & sneslib.KEY_LEFT != 0 and nes_oam[3] != 0) {
        const x = nes_oam[3] -% 2;
        nes_oam[3] = x;
        nes_oam[11] = x;
        nes_oam[7] = x +% 8;
        nes_oam[15] = x +% 8;
    }
    if (pad & sneslib.KEY_RIGHT != 0 and nes_oam[3] +% 12 != 254) {
        const x = nes_oam[3] +% 2;
        nes_oam[3] = x;
        nes_oam[11] = x;
        nes_oam[7] = x +% 8;
        nes_oam[15] = x +% 8;
    }
    // Fire: A or Y button
    if ((pad & (sneslib.KEY_A | sneslib.KEY_Y)) != 0 and nes_oam[16] == 0xFF) {
        nes_oam[16] = 192;
        nes_oam[17] = 4;
        nes_oam[18] = 0;
        nes_oam[19] = nes_oam[3] +% 6;
    }
}

fn movePlayerBullet() void {
    @setRuntimeSafety(false);
    if (nes_oam[16] == 0xFF) return;
    if (nes_oam[16] < 4) {
        nes_oam[16] = 0xFF;
    } else {
        nes_oam[16] -= 4;
    }
}

fn updatePalette() void {
    @setRuntimeSafety(false);
    if (frame_count & 7 == 0) {
        const tmp = pal1;
        pal1 = pal2;
        pal2 = tmp;
        sneslib.cgram_set(1, nesColor(pal1));
        sneslib.cgram_set(2, nesColor(pal2));
    }
    if (flash > 0) {
        flash -= 1;
        sneslib.cgram_set(0, nesColor(0x30));
    } else {
        sneslib.cgram_set(0, nesColor(0x0F));
    }
}

fn updateShake() void {
    @setRuntimeSafety(false);
    if (shake > 0) {
        shake -= 1;
        const sx: u8 = (shake & 1) * 4;
        hw.BG1HOFS.* = sx;
        hw.BG1HOFS.* = 0; // high byte (write-twice latch)
        hw.BG1VOFS.* = 0;
        hw.BG1VOFS.* = 0;
    } else {
        hw.BG1HOFS.* = 0;
        hw.BG1HOFS.* = 0;
        hw.BG1VOFS.* = 0;
        hw.BG1VOFS.* = 0;
    }
}

// ── PPU and screen setup ──────────────────────────────────────────────────────

fn setupPpu() void {
    hw.BGMODE.* = 0x01; // Mode 1: BG1+BG2 4bpp, BG3 2bpp
    hw.BG1SC.* = 0x00; // BG1 tilemap at VRAM word 0x0000, 32×32
    hw.BG12NBA.* = 0x02; // BG1 CHR base = word 0x2000 (value 2 × 0x1000 words)
    hw.OBSEL.* = 0x02; // OBJ CHR at VRAM word 0x4000 (value 2 × 0x2000 words), 8×8 small
    hw.TM.* = 0x11; // main screen: BG1 (bit0) + OBJ (bit4)
    sneslib.bg_scroll_zero();
}

fn clearTilemap() void {
    sneslib.vram_set_addr(0x0000);
    var i: u16 = 0;
    while (i < 1024) : (i += 1) sneslib.vram_write(0, 0x00);
}

fn displayTitleScreen() void {
    sneslib.ppu_off();
    @memset(&nes_oam, 0xFF);
    clearTilemap();
    const title = "M E G A  B L A S T";
    vramWriteRow(4, 6, title);
    const press = "PRESS FIRE TO BEGIN";
    vramWriteRow(20, 6, press);
    setupPpu();
    sneslib.ppu_on();
}

fn displayGameScreen() void {
    sneslib.ppu_off();
    @memset(&nes_oam, 0xFF);
    nes_oam[16] = 0xFF;
    clearTilemap();
    vramWriteRow(22, 0, &mountain_tiles);
    vramFillRow(26, 0, 9, 32);
    const score_hdr = "SCORE 0000000";
    vramWriteRow(25, 0, score_hdr);
    placeStars();
    setupPpu();
    sneslib.ppu_on();
}

// ── Main ──────────────────────────────────────────────────────────────────────

pub fn main() void {
    sneslib.ppu_off();
    hw.VMAIN.* = 0x80; // auto-increment VRAM address after VMDATAH write

    // Upload CHR data via DMA (force-blank active)
    sneslib.dma_copy_vram(&snes_chr_bg, 0x2000, @intCast(snes_chr_bg.len));
    sneslib.dma_copy_vram(&snes_chr_spr, 0x4000, @intCast(snes_chr_spr.len));

    // BG palette 0: CGRAM 0-15
    for (0..16) |j| sneslib.cgram_set(@intCast(j), nesColor(bg_palette[j]));
    // OBJ palettes 0-3: CGRAM 128-191 (16 entries each, we fill 4)
    for (0..4) |j| sneslib.cgram_set(@intCast(128 + j), nesColor(sp_palette[j]));
    for (0..4) |j| sneslib.cgram_set(@intCast(144 + j), nesColor(sp_palette[4 + j]));
    for (0..4) |j| sneslib.cgram_set(@intCast(160 + j), nesColor(sp_palette[8 + j]));
    for (0..4) |j| sneslib.cgram_set(@intCast(176 + j), nesColor(sp_palette[12 + j]));

    while (true) {
        // ── Title screen ──
        displayTitleScreen();
        while (true) {
            sneslib.wait_vblank();
            frame_count +%= 1;
            if (sneslib.pad_keys[0] & (sneslib.KEY_A | sneslib.KEY_B | sneslib.KEY_Y | sneslib.KEY_START) != 0) break;
        }
        // Seed RNG from elapsed frame time
        rng_state = @as(u16, frame_count) *% 0x1337 +% 1;
        if (rng_state == 0) rng_state = 0xACE1;

        // ── New game ──
        score = .{ 0, 0, 0 };
        lives = 5;
        player_dead = 0;
        level = 1;
        flash = 0;
        shake = 0;
        pal1 = bg_palette[1];
        pal2 = bg_palette[2];
        setupLevel();
        displayGameScreen();
        displayPlayer();
        // displayGameScreen() ends with ppu_on(); re-enter force-blank for safe initial HUD writes.
        sneslib.ppu_off();
        writeScore();
        writeHighScore();
        writeLives();
        writeLevelText();
        sneslib.ppu_on();
        score_dirty = false;
        highscore_dirty = false;
        lives_dirty = false;
        level_dirty = false;
        level_erase_dirty = false;
        gameover_dirty = false;

        // ── Main game loop ──
        var gameover_shown: bool = false;
        game_loop: while (true) {
            sneslib.wait_vblank();
            frame_count +%= 1;

            // OAM DMA (VBlank window)
            convertOam();
            sneslib.dma_copy_oam(&snes_oam, 544);

            // Deferred VRAM HUD writes (VBlank window)
            if (score_dirty) {
                score_dirty = false;
                writeScore();
            }
            if (highscore_dirty) {
                highscore_dirty = false;
                writeHighScore();
            }
            if (lives_dirty) {
                lives_dirty = false;
                writeLives();
            }
            if (level_dirty) {
                level_dirty = false;
                writeLevelText();
            }
            if (level_erase_dirty) {
                level_erase_dirty = false;
                writeLevelErase();
            }
            animateStars();
            if (gameover_dirty) {
                gameover_dirty = false;
                writeGameOver();
            }
            updatePalette();
            updateShake();

            // Game over state machine (logic only — hardware writes above in VBlank window)
            if (lives == 0 and player_dead != 0 and player_dead != 1) {
                if (player_dead == 20 and !gameover_shown) {
                    gameover_shown = true;
                    gameover_dirty = true;
                }
                if (player_dead == 240) break :game_loop;
                player_dead +%= 1;
                continue :game_loop;
            }

            const pad = sneslib.pad_keys[0];
            playerActions(pad);
            movePlayerBullet();
            spawnEnemy();
            moveEnemies();

            if (display_level > 0) {
                display_level -= 1;
                if (display_level == 0) level_erase_dirty = true;
            }
        }
        // Return to title screen
    }
}
