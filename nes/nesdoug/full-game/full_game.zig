// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES Full Game: Zig port of nesdoug CH26 scrolling platformer.
pub const panic = @import("mos_panic");

const neslib = @import("neslib");
const nesdoug = @import("nesdoug");

extern const music_data: u8;
extern const sounds_data: u8;

// ── constants ──────────────────────────────────────────────────────────────────
const LEFT: u8 = 0;
const RIGHT: u8 = 1;
const ACCEL: i16 = 0x30;
const GRAVITY: i16 = 0x50;
const MAX_SPEED: i16 = 0x240;
const JUMP_VEL: i16 = -0x600;
const HERO_WIDTH: u8 = 13;
const HERO_HEIGHT: u8 = 11;
const MAX_RIGHT: u16 = 0x9000;
const COL_DOWN: u8 = 0x80;
const COL_ALL: u8 = 0x40;
const COIN_WIDTH: u8 = 7;
const COIN_HEIGHT: u8 = 11;
const BIG_COIN: u8 = 13;
const ENEMY_WIDTH: u8 = 13;
const ENEMY_HEIGHT: u8 = 13;
const MAX_COINS: usize = 16;
const MAX_ENEMY: usize = 16;
const TURN_OFF: u8 = 0xff;
const MAX_SCROLL: u16 = 7 * 0x100 - 1; // 0x6FF

const MODE_TITLE: u8 = 0;
const MODE_GAME: u8 = 1;
const MODE_PAUSE: u8 = 2;
const MODE_SWITCH: u8 = 3;
const MODE_END: u8 = 4;
const MODE_GAME_OVER: u8 = 5;

const SONG_GAME: u8 = 0;
const SONG_PAUSE: u8 = 1;
const SFX_JUMP: u8 = 0;
const SFX_DING: u8 = 1;
const SFX_NOISE: u8 = 2;
const COIN_REG: u8 = 0;
const COIN_END: u8 = 1;
const ENEMY_CHASE: u8 = 0;
const ENEMY_BOUNCE: u8 = 1;

// ── data types ─────────────────────────────────────────────────────────────────
const Hero = extern struct {
    x: u16 = 0,
    y: u16 = 0,
    vel_x: i16 = 0,
    vel_y: i16 = 0,
};

const Box = extern struct {
    x: u8 = 0,
    y: u8 = 0,
    width: u8 = 0,
    height: u8 = 0,
};

// ── static ROM data ────────────────────────────────────────────────────────────
const palette_title = [16]u8{
    0x0f, 0x04, 0x15, 0x32,
    0,    0,    0,    0,
    0,    0,    0,    0,
    0,    0,    0,    0,
};
const palette_bg = [16]u8{
    0x22, 0x16, 0x36, 0x0f,
    0,    8,    0x18, 0x39,
    0,    0,    0x10, 0x20,
    0,    0x0a, 0x1a, 0x2a,
};
const palette_sp = [16]u8{
    0x22, 0x01, 0x11, 0x10,
    0x22, 0x17, 0x28, 0x38,
    0x22, 0x06, 0x16, 0x37,
    0x22, 0x03, 0x13, 0x33,
};

const title_scr = [147]u8{
    0x01, 0x00, 0x01, 0xfe, 0x00, 0x01, 0x0b, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88,
    0x89, 0x8a, 0x00, 0x01, 0x14, 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a,
    0x00, 0x01, 0x14, 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0x00, 0x01,
    0x32, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe,
    0x00, 0x01, 0x10, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xcb, 0xcc,
    0xcd, 0xce, 0x00, 0x01, 0x10, 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda,
    0xdb, 0xdc, 0xdd, 0xde, 0x00, 0x01, 0x10, 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8,
    0xe9, 0xea, 0xeb, 0xec, 0xed, 0xee, 0x00, 0x01, 0xaf, 0x32, 0x30, 0x31, 0x38, 0x00, 0x00, 0x44,
    0x6f, 0x75, 0x67, 0x00, 0x46, 0x72, 0x61, 0x6b, 0x65, 0x72, 0x00, 0x01, 0xfe, 0x00, 0x01, 0x46,
    0x00, 0x01, 0x00,
};

// 12 metatile definitions × 5 bytes (TL, TR, BL, BR, flags)
const metatiles1 = [60]u8{
    0,  0,  0,  0,  0,
    2,  2,  2,  2,  3,
    20, 20, 20, 20, 0,
    5,  6,  21, 22, 1,
    6,  6,  22, 22, 1,
    6,  7,  22, 23, 1,
    21, 22, 21, 22, 1,
    22, 22, 22, 22, 1,
    22, 23, 22, 23, 1,
    8,  9,  24, 25, 1,
    9,  9,  25, 25, 1,
    9,  10, 25, 26, 1,
};

// Solidity flags for each metatile index
const is_solid = [12]u8{ 0, COL_DOWN, COL_ALL | COL_DOWN, COL_DOWN, COL_DOWN, COL_DOWN, 0, 0, 0, 0, 0, 0 };

// ── metasprites (terminator = 128) ─────────────────────────────────────────────
const round_spr_l = [17]u8{ 0xff, 0xfc, 0x02, 0, 7, 0xfc, 0x03, 0, 0xff, 4, 0x12, 0, 7, 4, 0x13, 0, 128 };
const round_spr_r = [17]u8{ 0xff, 0xfc, 0x00, 0, 7, 0xfc, 0x01, 0, 0xff, 4, 0x10, 0, 7, 4, 0x11, 0, 128 };
const coin_spr = [9]u8{ 0xff, 0xff, 0x20, 1, 0xff, 7, 0x30, 1, 128 };
const big_coin_spr = [17]u8{ 0xff, 0xff, 0x21, 1, 0xff, 7, 0x31, 1, 7, 0xff, 0x22, 1, 7, 7, 0x32, 1, 128 };
const coin_hud = [17]u8{ 0, 0, 0x23, 1, 8, 0, 0x24, 1, 0, 8, 0x33, 1, 8, 8, 0x34, 1, 128 };
const enemy_chase_spr = [17]u8{ 0xff, 0xff, 0x04, 2, 7, 0xff, 0x05, 2, 0xff, 7, 0x14, 2, 7, 7, 0x15, 2, 128 };
const enemy_bounce_spr = [17]u8{ 0xff, 0xff, 0x06, 3, 7, 0xff, 0x07, 3, 0xff, 7, 0x16, 3, 7, 7, 0x17, 3, 128 };
const enemy_bounce_spr2 = [17]u8{ 0xff, 0xff, 0x04, 3, 7, 0xff, 0x05, 3, 0xff, 7, 0x14, 3, 7, 7, 0x15, 3, 128 };

// ── level room data (15 rows × 16 cols = 240 bytes each) ──────────────────────
const level1_0 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  3,  4,  4, 4,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  6,  7,  7, 7,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  6,  7,  7, 7,
    0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  6,  7,  7, 2,
    0, 0, 0, 0, 0, 0, 3, 4,  4,  4,  4,  4,  4,  5,  7, 2,
    0, 0, 0, 0, 0, 0, 9, 10, 10, 10, 10, 10, 10, 11, 7, 2,
    1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,  1,  1,  1, 1,
    1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,  1,  1,  1, 1,
};
const level1_1 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    4, 5, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    7, 8, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    7, 8, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0, 0, 0,
    2, 8, 0, 0, 0, 0, 0, 3, 4,  4,  4,  4,  5,  0, 0, 3,
    2, 8, 0, 0, 0, 0, 0, 6, 7,  7,  7,  7,  8,  0, 0, 6,
    2, 8, 0, 0, 2, 0, 0, 9, 10, 10, 10, 10, 11, 0, 0, 9,
    1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,  1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,  1, 1, 1,
};
const level1_2 = [240]u8{
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  0,  0,  0, 0, 0, 0,  0,  0,  0,
    0,  0,  0,  0, 0, 0, 0,  2,  0,  0, 0, 0, 0,  0,  0,  0,
    4,  4,  5,  0, 0, 3, 4,  4,  5,  0, 0, 3, 4,  4,  5,  0,
    7,  7,  8,  0, 0, 6, 7,  7,  8,  0, 0, 6, 7,  7,  8,  0,
    10, 10, 11, 0, 0, 9, 10, 10, 11, 0, 0, 9, 10, 10, 11, 0,
    1,  1,  1,  1, 1, 1, 1,  1,  1,  1, 1, 1, 1,  1,  1,  1,
    1,  1,  1,  1, 1, 1, 1,  1,  1,  1, 1, 1, 1,  1,  1,  1,
};
const level1_3 = [240]u8{
    0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 3, 4, 4, 4, 4, 4, 4,
    0, 0, 0, 0, 0,  0,  0,  0, 0, 6, 7, 7, 7, 7, 7, 7,
    0, 0, 0, 3, 4,  4,  5,  0, 0, 6, 7, 7, 7, 7, 7, 7,
    0, 0, 0, 6, 7,  7,  8,  0, 0, 6, 7, 7, 7, 7, 7, 7,
    0, 0, 2, 2, 10, 10, 11, 0, 0, 6, 7, 7, 7, 7, 7, 7,
    1, 1, 1, 1, 1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level1_4 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    4, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,
    7, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  3,  4,
    2, 2, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  6,  7,
    2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 3, 4,  4,  4,  4,  4,
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 9, 10, 10, 10, 10, 10,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1,  1,
};
const level1_5 = [240]u8{
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 2, 2, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    4,  4,  4,  5,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    7,  7,  7,  8,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0,
    4,  4,  4,  4,  4,  4,  4,  4,  5,  0, 0, 0, 0, 2, 2, 0,
    10, 10, 10, 10, 10, 10, 10, 10, 11, 0, 0, 0, 0, 2, 2, 0,
    1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1,
    1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1,
};
const level1_6 = [240]u8{
    0, 0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0,  0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0,  0,  0,  3,  4,  4, 4, 4, 5, 0, 0, 0, 0, 0, 0,
    0, 0,  0,  0,  6,  7,  7, 7, 7, 8, 0, 0, 0, 0, 0, 0,
    0, 0,  3,  4,  4,  4,  4, 4, 4, 5, 0, 0, 0, 0, 0, 0,
    0, 0,  6,  7,  7,  7,  7, 7, 7, 8, 0, 0, 0, 0, 0, 0,
    3, 4,  4,  4,  4,  5,  7, 7, 7, 8, 0, 0, 0, 0, 0, 0,
    6, 7,  7,  7,  7,  8,  7, 7, 7, 8, 0, 0, 0, 0, 0, 0,
    9, 10, 10, 10, 10, 11, 7, 7, 7, 8, 0, 0, 0, 0, 0, 0,
    1, 1,  1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1,  1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level1_7 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    3, 4, 4, 4, 4, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    6, 7, 7, 7, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    6, 7, 7, 7, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    6, 7, 7, 7, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    6, 7, 7, 7, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    6, 7, 7, 7, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    6, 7, 7, 7, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};

const level2_0 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level2_1 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 0, 0, 2, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level2_2 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 0, 0, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level2_3 = [240]u8{
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 0, 0, 0, 0,
    4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  5,  0, 0, 0, 0, 0,
    10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11, 0, 0, 0, 0, 0,
    1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 1, 1, 1, 1,
    1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 1, 1, 1, 1,
};
const level2_4 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 2,
    2, 2, 0, 0, 0, 2, 2, 0, 0, 0, 2, 2, 0, 0, 0, 2,
    2, 2, 0, 0, 0, 2, 2, 0, 0, 0, 2, 2, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level2_5 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 2, 2,
    0, 0, 0, 0, 2, 2, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0,
    2, 0, 0, 0, 2, 2, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0,
    2, 0, 0, 0, 2, 2, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0,
    2, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level2_6 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level2_7 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};

const level3_0 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 3, 4,  4,  5,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 6, 7,  7,  8,  0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 9, 10, 10, 11, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1,  1,  1,  1, 1, 1, 1, 1,
};
const level3_1 = [240]u8{
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,  0,  0,  0,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 3, 4,  4,  4,  5,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 6, 7,  7,  7,  8,  0, 0, 0, 0, 0, 0, 0, 0,
    0, 3, 4, 6, 7,  7,  7,  8,  0, 0, 2, 2, 0, 0, 0, 0,
    0, 6, 7, 9, 10, 10, 10, 11, 0, 0, 2, 2, 0, 0, 0, 0,
    1, 1, 1, 1, 1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1,
};
const level3_2 = [240]u8{
    0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0,
    0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 2,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level3_3 = [240]u8{
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level3_4 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level3_5 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level3_6 = [240]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};
const level3_7 = [240]u8{
    2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
};

// Flat list of all 24 rooms; Level_offsets[] = {0, 8, 16}
const levels_list: [24]*const [240]u8 = .{
    &level1_0, &level1_1, &level1_2, &level1_3,
    &level1_4, &level1_5, &level1_6, &level1_7,
    &level2_0, &level2_1, &level2_2, &level2_3,
    &level2_4, &level2_5, &level2_6, &level2_7,
    &level3_0, &level3_1, &level3_2, &level3_3,
    &level3_4, &level3_5, &level3_6, &level3_7,
};
const level_offsets = [3]u8{ 0, 8, 16 };

// ── object placement data (y, room, x, type; 0xff = end-of-list) ──────────────
const level_1_coins = [_]u8{
    0x90,     0, 0x70, COIN_REG,
    0x90,     0, 0x90, COIN_REG,
    0x50,     1, 0x40, COIN_REG,
    0x70,     2, 0x00, COIN_REG,
    0x50,     2, 0x70, COIN_REG,
    0x50,     3, 0xa0, COIN_REG,
    0x50,     3, 0xd0, COIN_REG,
    0x60,     4, 0xf0, COIN_REG,
    0x60,     5, 0x20, COIN_REG,
    0x30,     6, 0xc0, COIN_REG,
    0x30,     6, 0xe0, COIN_REG,
    0x30,     7, 0x80, COIN_REG,
    0xb0,     7, 0xc0, COIN_END,
    TURN_OFF,
};
const level_2_coins = [_]u8{
    0xa0,     1, 0x20, COIN_REG,
    0xa0,     1, 0x40, COIN_REG,
    0x60,     2, 0x70, COIN_REG,
    0x30,     3, 0x20, COIN_REG,
    0x30,     3, 0x70, COIN_REG,
    0xc0,     5, 0x00, COIN_REG,
    0xc0,     5, 0x50, COIN_REG,
    0x40,     6, 0x90, COIN_REG,
    0x40,     6, 0xd0, COIN_REG,
    0x40,     7, 0x40, COIN_REG,
    0xa0,     7, 0xc0, COIN_END,
    TURN_OFF,
};
const level_3_coins = [_]u8{
    0x80,     0, 0x80, COIN_REG,
    0x70,     1, 0x50, COIN_REG,
    0x80,     1, 0xd0, COIN_REG,
    0x80,     2, 0x40, COIN_REG,
    0x80,     2, 0x80, COIN_REG,
    0x80,     2, 0xc0, COIN_REG,
    0x80,     3, 0x30, COIN_REG,
    0x50,     7, 0x25, COIN_REG,
    0x50,     7, 0x80, COIN_END,
    0xb0,     7, 0xd0, COIN_REG,
    TURN_OFF,
};
const level_1_enemies = [_]u8{
    0xc0,     0, 0xc0, ENEMY_CHASE,
    0xc0,     1, 0xe0, ENEMY_BOUNCE,
    0xc0,     2, 0x30, ENEMY_BOUNCE,
    0xc0,     2, 0x90, ENEMY_CHASE,
    0xb0,     3, 0x20, ENEMY_BOUNCE,
    0xc0,     3, 0xb0, ENEMY_CHASE,
    0x80,     5, 0x00, ENEMY_BOUNCE,
    0xc0,     5, 0x90, ENEMY_CHASE,
    0xc0,     6, 0x70, ENEMY_CHASE,
    TURN_OFF,
};
const level_2_enemies = [_]u8{
    0xc0,     0, 0x90, ENEMY_CHASE,
    0xc0,     1, 0xd0, ENEMY_CHASE,
    0x40,     3, 0x40, ENEMY_BOUNCE,
    0xc0,     4, 0x30, ENEMY_BOUNCE,
    0xc0,     4, 0x80, ENEMY_BOUNCE,
    0xc0,     6, 0x20, ENEMY_CHASE,
    0xc0,     7, 0x20, ENEMY_BOUNCE,
    0xc0,     7, 0x60, ENEMY_BOUNCE,
    TURN_OFF,
};
const level_3_enemies = [_]u8{
    0xc0,     0, 0xc0, ENEMY_BOUNCE,
    0xc0,     0, 0xf0, ENEMY_BOUNCE,
    0xc0,     1, 0x80, ENEMY_CHASE,
    0xc0,     1, 0xd0, ENEMY_CHASE,
    0xc0,     2, 0x40, ENEMY_BOUNCE,
    0xc0,     2, 0x80, ENEMY_BOUNCE,
    0xc0,     2, 0xc0, ENEMY_BOUNCE,
    0xb0,     3, 0x10, ENEMY_BOUNCE,
    0xb0,     4, 0x60, ENEMY_CHASE,
    0x90,     5, 0x40, ENEMY_BOUNCE,
    0x90,     6, 0x50, ENEMY_BOUNCE,
    0xa0,     6, 0xc0, ENEMY_BOUNCE,
    0xc0,     7, 0xe0, ENEMY_CHASE,
    TURN_OFF,
};

const coins_list: [3][*]const u8 = .{ &level_1_coins, &level_2_coins, &level_3_coins };
const enemy_list: [3][*]const u8 = .{ &level_1_enemies, &level_2_enemies, &level_3_enemies };

// ── mutable game state ─────────────────────────────────────────────────────────
var box_guy1 = Hero{};
var c_map: [240]u8 = undefined;
var c_map2: [240]u8 = undefined;

var pad1: u8 = 0;
var pad1_new: u8 = 0;
var collision_l: u8 = 0;
var collision_r: u8 = 0;
var collision_u: u8 = 0;
var collision_d: u8 = 0;
var eject_l: u8 = 0;
var eject_r: u8 = 0;
var eject_d: u8 = 0;
var eject_u: u8 = 0;
var direction: u8 = RIGHT;

var scroll_x: u16 = 0;
var scroll_count: u8 = 0;
var l_r_switch: u8 = 0;

var song: u8 = SONG_GAME;
var game_mode: u8 = MODE_TITLE;

var coins: u8 = 0;
var level: u8 = 0;
var level_up: u8 = 0;
var death: u8 = 0;
var map_loaded: u8 = 0;
var enemy_frames: u8 = 0;

var coin_x: [MAX_COINS]u8 = [_]u8{0} ** MAX_COINS;
var coin_y: [MAX_COINS]u8 = [_]u8{TURN_OFF} ** MAX_COINS;
var coin_active: [MAX_COINS]u8 = [_]u8{0} ** MAX_COINS;
var coin_room: [MAX_COINS]u8 = [_]u8{0} ** MAX_COINS;
var coin_actual_x: [MAX_COINS]u8 = [_]u8{0} ** MAX_COINS;
var coin_type: [MAX_COINS]u8 = [_]u8{0} ** MAX_COINS;

var enemy_x: [MAX_ENEMY]u8 = [_]u8{0} ** MAX_ENEMY;
var enemy_y: [MAX_ENEMY]u8 = [_]u8{TURN_OFF} ** MAX_ENEMY;
var enemy_active: [MAX_ENEMY]u8 = [_]u8{0} ** MAX_ENEMY;
var enemy_room: [MAX_ENEMY]u8 = [_]u8{0} ** MAX_ENEMY;
var enemy_actual_x: [MAX_ENEMY]u8 = [_]u8{0} ** MAX_ENEMY;
var enemy_type: [MAX_ENEMY]u8 = [_]u8{0} ** MAX_ENEMY;
var enemy_anim: [MAX_ENEMY]?*const anyopaque = [_]?*const anyopaque{null} ** MAX_ENEMY;

// Persistent loop state
var short_jump_count: u8 = 0;
var bright: u8 = 0;
var bright_count: u8 = 0;

// ── helpers ────────────────────────────────────────────────────────────────────
inline fn hiB(v: u16) u8 {
    return @truncate(v >> 8);
}
inline fn setHiB(v: *u16, b: u8) void {
    v.* = (v.* & 0x00ff) | (@as(u16, b) << 8);
}
inline fn ntadrA(x: u8, y: u8) i16 {
    return @as(i16, @intCast(0x2000 | (@as(u16, y) << 5) | @as(u16, x)));
}

// ── bg collision ───────────────────────────────────────────────────────────────
fn bgCollisionSub(x: u16, y: u8) u8 {
    const upper_left: u8 = @as(u8, @truncate((x & 0xff) >> 4)) +% (y & 0xf0);
    const typ: u8 = if (x & 0x100 != 0) c_map2[upper_left] else c_map[upper_left];
    return is_solid[typ];
}

fn bgCollisionFast(x: u8, y: u8, width: u8) void {
    collision_l = 0;
    collision_r = 0;
    if (y >= 0xf0) return;
    const upper_left: u16 = @as(u16, x) +% scroll_x;
    if (bgCollisionSub(upper_left, y) & COL_ALL != 0) collision_l +%= 1;
    const upper_right: u16 = upper_left +% @as(u16, width);
    if (bgCollisionSub(upper_right, y) & COL_ALL != 0) collision_r +%= 1;
}

fn bgCollision(x: u8, y: u8, width: u8, height: u8) void {
    collision_l = 0;
    collision_r = 0;
    collision_u = 0;
    collision_d = 0;
    if (y >= 0xf0) return;

    const x_upper_left: u16 = @as(u16, x) +% scroll_x;
    eject_l = @as(u8, @truncate(x_upper_left & 0xff)) | 0xf0;

    var y_top = y;
    eject_u = y_top | 0xf0;
    if (l_r_switch != 0) y_top +%= 2;

    if (bgCollisionSub(x_upper_left, y_top) & COL_ALL != 0) {
        collision_l +%= 1;
        collision_u +%= 1;
    }

    const x_upper_right: u16 = x_upper_left +% @as(u16, width);
    eject_r = @as(u8, @truncate((x_upper_right +% 1) & 0x0f));

    if (bgCollisionSub(x_upper_right, y_top) & COL_ALL != 0) {
        collision_r +%= 1;
        collision_u +%= 1;
    }

    var y_bot: u8 = y +% height;
    if (l_r_switch != 0) y_bot -%= 2;
    eject_d = @as(u8, @truncate((y_bot +% 1) & 0x0f));
    if (y_bot >= 0xf0) return;

    const col_br = bgCollisionSub(x_upper_right, y_bot);
    if (col_br & COL_ALL != 0) collision_r +%= 1;
    if (col_br & (COL_DOWN | COL_ALL) != 0) collision_d +%= 1;

    const col_bl = bgCollisionSub(x_upper_left, y_bot);
    if (col_bl & COL_ALL != 0) collision_l +%= 1;
    if (col_bl & (COL_DOWN | COL_ALL) != 0) collision_d +%= 1;

    if ((y_bot & 0x0f) > 3) collision_d = 0;
}

fn bgCheckLow(x: u8, y: u8, width: u8, height: u8) void {
    collision_d = 0;
    const x_left: u16 = @as(u16, x) +% scroll_x;
    const y_bot: u8 = y +% height +% 1;
    if (y_bot >= 0xf0) return;
    if (bgCollisionSub(x_left, y_bot) & (COL_DOWN | COL_ALL) != 0) collision_d +%= 1;
    const x_right: u16 = x_left +% @as(u16, width);
    if (bgCollisionSub(x_right, y_bot) & (COL_DOWN | COL_ALL) != 0) collision_d +%= 1;
    if ((y_bot & 0x0f) > 3) collision_d = 0;
}

// ── sprite object initialise ───────────────────────────────────────────────────
fn spriteObjInit() void {
    const cptr: [*]const u8 = coins_list[level];
    var i: usize = 0;
    var j: usize = 0;
    while (i < MAX_COINS) : (i += 1) {
        coin_x[i] = 0;
        coin_y[i] = cptr[j];
        if (coin_y[i] == TURN_OFF) break;
        coin_active[i] = 0;
        j += 1;
        coin_room[i] = cptr[j];
        j += 1;
        coin_actual_x[i] = cptr[j];
        j += 1;
        coin_type[i] = cptr[j];
        j += 1;
    }
    i += 1;
    while (i < MAX_COINS) : (i += 1) coin_y[i] = TURN_OFF;

    const eptr: [*]const u8 = enemy_list[level];
    i = 0;
    j = 0;
    while (i < MAX_ENEMY) : (i += 1) {
        enemy_x[i] = 0;
        enemy_y[i] = eptr[j];
        if (enemy_y[i] == TURN_OFF) break;
        enemy_active[i] = 0;
        j += 1;
        enemy_room[i] = eptr[j];
        j += 1;
        enemy_actual_x[i] = eptr[j];
        j += 1;
        enemy_type[i] = eptr[j];
        j += 1;
    }
    i += 1;
    while (i < MAX_ENEMY) : (i += 1) enemy_y[i] = TURN_OFF;
}

// ── load title / load room ─────────────────────────────────────────────────────
fn loadTitle() void {
    neslib.pal_bg(&palette_title);
    neslib.pal_spr(&palette_sp);
    neslib.vram_adr(0x2000);
    neslib.vram_unrle(&title_scr);
    game_mode = MODE_TITLE;
}

fn loadRoom() void {
    const offset: usize = level_offsets[level];
    nesdoug.set_data_pointer(levels_list[offset]);
    nesdoug.set_mt_pointer(&metatiles1);

    var y: u8 = 0;
    while (true) {
        var x: u8 = 0;
        while (true) {
            nesdoug.buffer_4_mt(nesdoug.get_ppu_addr(0, x, y), (y & 0xf0) +% (x >> 4));
            nesdoug.flush_vram_update2();
            if (x == 0xe0) break;
            x +%= 0x20;
        }
        if (y == 0xe0) break;
        y +%= 0x20;
    }

    // Draw first column of next room into nametable B
    nesdoug.set_data_pointer(levels_list[offset + 1]);
    y = 0;
    while (true) {
        nesdoug.buffer_4_mt(nesdoug.get_ppu_addr(1, 0, y), y & 0xf0);
        nesdoug.flush_vram_update2();
        if (y == 0xe0) break;
        y +%= 0x20;
    }

    @memcpy(&c_map, levels_list[offset]);
    spriteObjInit();

    box_guy1.x = 0x4000;
    box_guy1.y = 0xc400;
    box_guy1.vel_x = 0;
    box_guy1.vel_y = 0;
    map_loaded = 0;
}

// ── draw sprites ───────────────────────────────────────────────────────────────
fn drawSprites() void {
    neslib.oam_clear();

    var hx: u8 = hiB(box_guy1.x);
    if (hx > 0xfc or hx == 0) hx = 1;
    neslib.oam_meta_spr(hx, hiB(box_guy1.y), if (direction == LEFT) &round_spr_l else &round_spr_r);

    for (0..MAX_COINS) |i| {
        var cy = coin_y[i];
        if (cy == TURN_OFF) continue;
        if (nesdoug.get_frame_count() & 8 != 0) cy +%= 1;
        if (coin_active[i] == 0 or coin_x[i] > 0xf0) continue;
        if (cy < 0xf0) neslib.oam_meta_spr(coin_x[i], cy, if (coin_type[i] == COIN_REG) &coin_spr else &big_coin_spr);
    }

    const shuffle_array = [64]u8{
        0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15,
        15, 14, 13, 12, 11, 10, 9,  8,  7,  6,  5,  4,  3,  2,  1,  0,
        0,  2,  4,  6,  8,  10, 12, 14, 1,  3,  5,  7,  9,  11, 13, 15,
        15, 13, 11, 9,  7,  5,  3,  1,  14, 12, 10, 8,  6,  4,  2,  0,
    };
    var soff: u8 = (@as(u8, nesdoug.get_frame_count()) & 3) *% 16;
    for (0..MAX_ENEMY) |_| {
        const j: usize = shuffle_array[soff];
        soff +%= 1;
        if (enemy_y[j] == TURN_OFF) continue;
        if (enemy_active[j] == 0) continue;
        var ex: u8 = enemy_x[j];
        if (ex == 0) ex = 1;
        if (ex > 0xf0) continue;
        if (enemy_y[j] < 0xf0) {
            if (enemy_anim[j]) |anim| neslib.oam_meta_spr(ex, enemy_y[j], anim);
        }
    }

    neslib.oam_meta_spr(0x10, 0x0f, &coin_hud);
    neslib.oam_spr(0x20, 0x17, (coins / 10) +% 0xf0, 1);
    neslib.oam_spr(0x28, 0x17, (coins % 10) +% 0xf0, 1);
}

// ── enemy moves ────────────────────────────────────────────────────────────────
fn enemyMoves(index: usize) void {
    if (enemy_type[index] == ENEMY_CHASE) {
        const ex: u8 = enemy_x[index];
        const ey: u8 = enemy_y[index] +% 6;
        enemy_anim[index] = &enemy_chase_spr;
        if (enemy_frames & 1 != 0) return;
        if (enemy_x[index] > hiB(box_guy1.x)) {
            bgCollisionFast(ex -% 1, ey, 13);
            if (collision_l != 0) return;
            if (enemy_actual_x[index] == 0) enemy_room[index] -%= 1;
            enemy_actual_x[index] -%= 1;
        } else if (enemy_x[index] < hiB(box_guy1.x)) {
            bgCollisionFast(ex +% 1, ey, 13);
            if (collision_r != 0) return;
            enemy_actual_x[index] +%= 1;
            if (enemy_actual_x[index] == 0) enemy_room[index] +%= 1;
        }
    } else if (enemy_type[index] == ENEMY_BOUNCE) {
        const anim_frame: u8 = (enemy_frames +% (@as(u8, @intCast(index)) << 3)) & 0x3f;
        if (anim_frame < 16) {
            enemy_anim[index] = &enemy_bounce_spr;
        } else if (anim_frame < 40) {
            enemy_y[index] -%= 1;
            enemy_anim[index] = &enemy_bounce_spr2;
        } else {
            enemy_anim[index] = &enemy_bounce_spr2;
            bgCheckLow(enemy_x[index], enemy_y[index] -% 1, 15, 15);
            if (collision_d == 0) enemy_y[index] +%= 1;
        }
    }
}

// ── check sprite objects (sets active flags, calls enemyMoves) ─────────────────
fn checkSprObjects() void {
    enemy_frames +%= 1;
    for (0..MAX_COINS) |i| {
        coin_active[i] = 0;
        if (coin_y[i] != TURN_OFF) {
            const x: u16 = ((@as(u16, coin_room[i]) << 8) | @as(u16, coin_actual_x[i])) -% scroll_x;
            coin_active[i] = if (hiB(x) == 0) 1 else 0;
            coin_x[i] = @truncate(x & 0xff);
        }
    }
    for (0..MAX_ENEMY) |i| {
        enemy_active[i] = 0;
        if (enemy_y[i] != TURN_OFF) {
            const x: u16 = ((@as(u16, enemy_room[i]) << 8) | @as(u16, enemy_actual_x[i])) -% scroll_x;
            enemy_active[i] = if (hiB(x) == 0) 1 else 0;
            if (enemy_active[i] == 0) continue;
            enemy_x[i] = @truncate(x & 0xff);
            enemyMoves(i);
        }
    }
}

// ── player movement ────────────────────────────────────────────────────────────
fn movement() void {
    // x axis
    const old_x: u8 = @truncate(box_guy1.x);

    if (pad1 & neslib.PAD_LEFT != 0) {
        direction = LEFT;
        if (box_guy1.x <= 0x100) {
            box_guy1.vel_x = 0;
            box_guy1.x = 0x100;
        } else if (box_guy1.x < 0x400) {
            box_guy1.vel_x = -0x100;
        } else {
            box_guy1.vel_x -%= ACCEL;
            if (box_guy1.vel_x < -MAX_SPEED) box_guy1.vel_x = -MAX_SPEED;
        }
    } else if (pad1 & neslib.PAD_RIGHT != 0) {
        direction = RIGHT;
        box_guy1.vel_x +%= ACCEL;
        if (box_guy1.vel_x > MAX_SPEED) box_guy1.vel_x = MAX_SPEED;
    } else {
        if (box_guy1.vel_x >= 0x100) {
            box_guy1.vel_x -%= ACCEL;
        } else if (box_guy1.vel_x < -0x100) {
            box_guy1.vel_x +%= ACCEL;
        } else {
            box_guy1.vel_x = 0;
        }
    }

    box_guy1.x +%= @as(u16, @bitCast(box_guy1.vel_x));

    if (box_guy1.x > 0xf800) {
        box_guy1.x = 0x100;
        box_guy1.vel_x = 0;
    }

    l_r_switch = 1;
    bgCollision(hiB(box_guy1.x), hiB(box_guy1.y), HERO_WIDTH, HERO_HEIGHT);

    if (collision_r != 0 and collision_l != 0) {
        box_guy1.x = @as(u16, old_x);
        box_guy1.vel_x = 0;
    } else if (collision_l != 0) {
        box_guy1.vel_x = 0;
        setHiB(&box_guy1.x, hiB(box_guy1.x) -% eject_l);
    } else if (collision_r != 0) {
        box_guy1.vel_x = 0;
        setHiB(&box_guy1.x, hiB(box_guy1.x) -% eject_r);
    }

    // y axis: gravity
    if (box_guy1.vel_y < 0x300) {
        box_guy1.vel_y +%= GRAVITY;
    } else {
        box_guy1.vel_y = 0x300;
    }
    box_guy1.y +%= @as(u16, @bitCast(box_guy1.vel_y));

    l_r_switch = 0;
    bgCollision(hiB(box_guy1.x), hiB(box_guy1.y), HERO_WIDTH, HERO_HEIGHT);

    if (collision_u != 0) {
        setHiB(&box_guy1.y, hiB(box_guy1.y) -% eject_u);
        box_guy1.vel_y = 0;
    } else if (collision_d != 0) {
        setHiB(&box_guy1.y, hiB(box_guy1.y) -% eject_d);
        box_guy1.y &= 0xff00;
        if (box_guy1.vel_y > 0) box_guy1.vel_y = 0;
    }

    // Jump check (one pixel below feet)
    bgCheckLow(hiB(box_guy1.x), hiB(box_guy1.y), HERO_WIDTH, HERO_HEIGHT);
    if (collision_d != 0) {
        if (pad1_new & neslib.PAD_A != 0) {
            box_guy1.vel_y = JUMP_VEL;
            neslib.sfx_play(SFX_JUMP, 0);
            short_jump_count = 1;
        }
    }

    // Shorter jump on button release
    if (short_jump_count != 0) {
        short_jump_count +%= 1;
        if (short_jump_count > 30) short_jump_count = 0;
    }
    if (short_jump_count != 0 and (pad1 & neslib.PAD_A == 0) and box_guy1.vel_y < -0x200) {
        box_guy1.vel_y = -0x200;
        short_jump_count = 0;
    }

    // Reload collision map at room boundary
    if ((scroll_x & 0xff) < 4) {
        if (map_loaded == 0) {
            newCmap();
            map_loaded = 1;
        }
    } else {
        map_loaded = 0;
    }

    // Scroll camera right behind player
    const new_x = box_guy1.x;
    if (box_guy1.x > MAX_RIGHT) {
        const scroll_amt: u8 = @truncate((box_guy1.x -% MAX_RIGHT) >> 8);
        scroll_x +%= @as(u16, scroll_amt);
        setHiB(&box_guy1.x, hiB(box_guy1.x) -% scroll_amt);
    }
    if (scroll_x >= MAX_SCROLL) {
        scroll_x = MAX_SCROLL;
        box_guy1.x = new_x;
        if (hiB(box_guy1.x) >= 0xf1) box_guy1.x = 0xf100;
    }
}

// ── draw screen column (called each frame to update the nametable) ─────────────
fn drawScreenR() void {
    const pseudo_scroll_x: u16 = scroll_x +% 0x120;
    const room: u8 = @truncate(pseudo_scroll_x >> 8);
    const nt: u8 = room & 1;
    const x: u8 = @truncate(pseudo_scroll_x & 0xff);
    const offset: u8 = scroll_count *% 0x40;

    nesdoug.set_data_pointer(levels_list[@as(usize, level_offsets[level]) + room]);
    nesdoug.buffer_4_mt(nesdoug.get_ppu_addr(nt, x, offset), offset +% (x >> 4));
    nesdoug.buffer_4_mt(nesdoug.get_ppu_addr(nt, x, offset +% 0x20), offset +% 0x20 +% (x >> 4));

    scroll_count +%= 1;
    scroll_count &= 3;
}

// ── copy new collision map when crossing a room boundary ───────────────────────
fn newCmap() void {
    const room: u8 = @truncate((scroll_x >> 8) +% 1);
    const map: *[240]u8 = if (room & 1 != 0) &c_map2 else &c_map;
    @memcpy(map, levels_list[@as(usize, level_offsets[level]) + room]);
}

// ── sprite collisions ──────────────────────────────────────────────────────────
fn spriteCollisions() void {
    var bg1 = Box{ .x = hiB(box_guy1.x), .y = hiB(box_guy1.y), .width = HERO_WIDTH, .height = HERO_HEIGHT };
    var other = Box{};

    for (0..MAX_COINS) |i| {
        if (coin_active[i] == 0) continue;
        if (coin_type[i] == COIN_REG) {
            other.width = COIN_WIDTH;
            other.height = COIN_HEIGHT;
        } else {
            other.width = BIG_COIN;
            other.height = BIG_COIN;
        }
        other.x = coin_x[i];
        other.y = coin_y[i];
        if (nesdoug.check_collision(&bg1, &other) == 0) continue;
        coin_y[i] = TURN_OFF;
        neslib.sfx_play(SFX_DING, 0);
        coins +%= 1;
        if (coin_type[i] == COIN_END) level_up +%= 1;
    }

    other.width = ENEMY_WIDTH;
    other.height = ENEMY_HEIGHT;
    for (0..MAX_ENEMY) |i| {
        if (enemy_active[i] == 0) continue;
        other.x = enemy_x[i];
        other.y = enemy_y[i];
        if (nesdoug.check_collision(&bg1, &other) == 0) continue;
        enemy_y[i] = TURN_OFF;
        enemy_active[i] = 0;
        neslib.sfx_play(SFX_NOISE, 0);
        if (coins != 0) {
            coins -%= 5;
            if (coins > 0x80) coins = 0;
        } else {
            death +%= 1;
        }
    }
}

// ── main ───────────────────────────────────────────────────────────────────────
pub export fn main() callconv(.c) void {
    neslib.music_init(&music_data);
    neslib.sounds_init(&sounds_data);

    neslib.ppu_off();
    neslib.bank_spr(1);
    nesdoug.set_vram_buffer();

    loadTitle();
    neslib.ppu_on_all();
    scroll_x = 0;
    nesdoug.set_scroll_x(scroll_x);

    while (true) {
        // ── title screen ──────────────────────────────────────────────────────
        while (game_mode == MODE_TITLE) {
            neslib.ppu_wait_nmi();
            nesdoug.set_music_speed(8);

            const title_color_rotate = [4]u8{ 0x32, 0x22, 0x30, 0x37 };
            neslib.pal_col(3, title_color_rotate[(@as(usize, nesdoug.get_frame_count()) >> 3) & 3]);

            pad1 = neslib.pad_poll(0);
            pad1_new = nesdoug.get_pad_new(0);

            if (pad1_new & neslib.PAD_START != 0) {
                nesdoug.pal_fade_to(4, 0);
                neslib.ppu_off();
                loadRoom();
                game_mode = MODE_GAME;
                neslib.pal_bg(&palette_bg);
                song = SONG_GAME;
                neslib.music_play(song);
                scroll_x = 0;
                nesdoug.set_scroll_x(scroll_x);
                neslib.ppu_on_all();
                neslib.pal_bright(4);
            }
        }

        // ── game loop ─────────────────────────────────────────────────────────
        while (game_mode == MODE_GAME) {
            neslib.ppu_wait_nmi();
            nesdoug.set_music_speed(8);

            pad1 = neslib.pad_poll(0);
            pad1_new = nesdoug.get_pad_new(0);

            movement();
            checkSprObjects();
            spriteCollisions();

            nesdoug.set_scroll_x(scroll_x);
            drawScreenR();
            drawSprites();

            if (pad1_new & neslib.PAD_START != 0) {
                game_mode = MODE_PAUSE;
                song = SONG_PAUSE;
                neslib.music_play(song);
                nesdoug.color_emphasis(nesdoug.COL_EMP_DARK);
                break;
            }

            if (level_up != 0) {
                game_mode = MODE_SWITCH;
                level_up = 0;
                bright = 4;
                bright_count = 0;
                level +%= 1;
            } else if (death != 0) {
                death = 0;
                bright = 0;
                scroll_x = 0;
                nesdoug.set_scroll_x(scroll_x);
                neslib.ppu_off();
                neslib.delay(5);
                neslib.oam_clear();
                game_mode = MODE_GAME_OVER;
                neslib.vram_adr(0x2000);
                neslib.vram_fill(0, 1024);
                neslib.ppu_on_all();
            }
        }

        // ── switch level / room ───────────────────────────────────────────────
        while (game_mode == MODE_SWITCH) {
            neslib.ppu_wait_nmi();
            bright_count +%= 1;
            if (bright_count >= 0x10) {
                bright_count = 0;
                bright -%= 1;
                if (bright != 0xff) neslib.pal_bright(bright);
            }
            nesdoug.set_scroll_x(scroll_x);

            if (bright == 0xff) {
                neslib.ppu_off();
                neslib.oam_clear();
                scroll_x = 0;
                nesdoug.set_scroll_x(scroll_x);
                if (level < 3) {
                    loadRoom();
                    game_mode = MODE_GAME;
                    neslib.ppu_on_all();
                    neslib.pal_bright(4);
                } else {
                    game_mode = MODE_END;
                    neslib.vram_adr(0x2000);
                    neslib.vram_fill(0, 1024);
                    neslib.ppu_on_all();
                    neslib.pal_bright(4);
                }
            }
        }

        // ── pause ─────────────────────────────────────────────────────────────
        while (game_mode == MODE_PAUSE) {
            neslib.ppu_wait_nmi();
            pad1 = neslib.pad_poll(0);
            pad1_new = nesdoug.get_pad_new(0);
            drawSprites();
            if (pad1_new & neslib.PAD_START != 0) {
                game_mode = MODE_GAME;
                song = SONG_GAME;
                neslib.music_play(song);
                nesdoug.color_emphasis(nesdoug.COL_EMP_NORMAL);
            }
        }

        // ── end screen ────────────────────────────────────────────────────────
        while (game_mode == MODE_END) {
            neslib.ppu_wait_nmi();
            neslib.oam_clear();
            nesdoug.multi_vram_buffer_horz("The end of the game.\x00", 21, ntadrA(6, 13));
            nesdoug.multi_vram_buffer_horz("I guess you won?\x00", 17, ntadrA(8, 15));
            nesdoug.multi_vram_buffer_horz("Coins: \x00", 8, ntadrA(11, 17));
            nesdoug.one_vram_buffer((coins / 10) +% 0x30, ntadrA(18, 17));
            nesdoug.one_vram_buffer((coins % 10) +% 0x30, ntadrA(19, 17));
            nesdoug.set_scroll_x(0);
            neslib.music_stop();
        }

        // ── game over ─────────────────────────────────────────────────────────
        while (game_mode == MODE_GAME_OVER) {
            neslib.ppu_wait_nmi();
            neslib.oam_clear();
            nesdoug.multi_vram_buffer_horz("You died.\x00", 10, ntadrA(12, 14));
            nesdoug.set_scroll_x(0);
            neslib.music_stop();
        }
    }
}
