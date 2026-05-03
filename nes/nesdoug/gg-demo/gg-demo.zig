// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES Game Genie demo: metatile font + nametable scrolling + player physics.
//! Zig port of llvm-mos-game-genie-jam (NROM 16KB PRG / 8KB CHR, vertical mirror).
pub const panic = @import("mos_panic");
const neslib = @import("neslib");
const nesdoug = @import("nesdoug");

const nametable_rle: []const u8 = @embedFile("default-nametable-rle.nam");

// nesdoug VRAM buffer — 128 bytes, index is a zero-page byte
extern var VRAM_BUF: [128]u8;
extern var VRAM_INDEX: u8;
extern var NAME_UPD_ENABLE: u8;

const NT_UPD_VERT: u8 = 0x80;
const NAMETABLE_B: c_int = 0x2400;
const PAD_A: u8 = 0x80;
const PAD_SELECT: u8 = 0x20;
const PAD_LEFT: u8 = 0x02;
const PAD_RIGHT: u8 = 0x01;
const OAM_FLIP_V: u8 = 0x80;

const Nametable = enum(u8) {
    A = 0x00,
    B = 0x04,
    C = 0x08,
    D = 0x0C,
};

// 2-wide × 3-tall metatile: each byte packs left nibble (high) + right nibble (low) CHR tile index
const Metatile23 = struct {
    top_top: u8,
    top_bot: u8,
    bot_top: u8,
};

const palette: [32]u8 = .{
    // BG: only colour 0 and 3 active (Game Genie hardware limitation)
    0x0f, 0x0f, 0x0f, 0x30,
    0x0f, 0x0f, 0x0f, 0x22,
    0x0f, 0x0f, 0x0f, 0x15,
    0x0f, 0x0f, 0x0f, 0x0f,
    // Sprite
    0x0f, 0x0f, 0x0f, 0x30,
    0x0f, 0x0f, 0x0f, 0x0f,
    0x0f, 0x0f, 0x0f, 0x0f,
    0x0f, 0x0f, 0x0f, 0x0f,
};

// ─── comptime font parsing (ported from metatile.hpp parse_string_mt_2_3) ───

fn getTileForBits(bits: u4) u8 {
    const t = [16]u8{ 0x0, 0x2, 0x1, 0x3, 0x8, 0xa, 0x9, 0xb, 0x4, 0x6, 0x5, 0x7, 0xc, 0xe, 0xd, 0xf };
    return t[bits];
}

fn combineBitsToTile(bits: u64, comptime offset: u6) u8 {
    const left: u4 = @truncate(((bits >> (offset + 10)) & 3) << 2 | ((bits >> (offset + 2)) & 3));
    const right: u4 = @truncate(((bits >> (offset + 8)) & 3) << 2 | ((bits >> offset) & 3));
    return (getTileForBits(left) << 4) | getTileForBits(right);
}

// Parses a 4×6 ASCII-art glyph string (`| o  |` format) into a Metatile23.
// Algorithm mirrors parse_string_mt_4_4 → parse_string_mt_2_3 from metatile.hpp.
fn parseMt23(comptime text: []const u8) Metatile23 {
    var bits: u64 = 0;
    var i: usize = 0;
    var c: u8 = if (text.len > 0) text[0] else 0;
    for (0..8) |_| {
        // skip to next '|' — post-increment (matches C++ text[i++])
        while (c != '|' and i < text.len) {
            c = text[i];
            i += 1;
        }
        // skip the opening '|' — post-increment: re-reads '|' on row 0, giving zeros
        if (c == '|') {
            c = if (i < text.len) text[i] else 0;
            i += 1;
        }
        // read 8 pixel columns; stop advancing on '|' or '\n' (remaining cols = 0)
        for (0..8) |_| {
            const v: u64 = if (c == ' ' or c == '|' or c == '\n' or c == 0) 0 else 1;
            bits = (bits << 1) | v;
            if (c != '|' and c != '\n' and c != 0) {
                c = if (i < text.len) text[i] else 0;
                i += 1;
            }
        }
        // advance past end of line
        while (c != '\n' and i < text.len) {
            c = text[i];
            i += 1;
        }
    }
    return .{
        .top_top = combineBitsToTile(bits, 52),
        .top_bot = combineBitsToTile(bits, 36),
        .bot_top = combineBitsToTile(bits, 20),
    };
}

// Font glyph strings in order: 0-9, A-Z, SPACE (37 total).
// Each row is 4 chars wide between '|' delimiters, 6 rows per glyph.
const font_strings = [37][]const u8{
    "| o  |\n|o o |\n|o o |\n|o o |\n| o  |\n|    |\n", // 0
    "| o  |\n|oo  |\n| o  |\n| o  |\n|ooo |\n|    |\n", // 1
    "|oo  |\n|  o |\n| o  |\n|o   |\n|ooo |\n|    |\n", // 2
    "|ooo |\n|  o |\n| oo |\n|  o |\n|ooo |\n|    |\n", // 3
    "|o o |\n|o o |\n|ooo |\n|  o |\n|  o |\n|    |\n", // 4
    "|ooo |\n|o   |\n|ooo |\n|  o |\n|ooo |\n|    |\n", // 5
    "|ooo |\n|o   |\n|ooo |\n|o o |\n|ooo |\n|    |\n", // 6
    "|ooo |\n|  o |\n|  o |\n|  o |\n|  o |\n|    |\n", // 7
    "|ooo |\n|o o |\n|ooo |\n|o o |\n|ooo |\n|    |\n", // 8
    "|ooo |\n|o o |\n|ooo |\n|  o |\n|  o |\n|    |\n", // 9
    "| o  |\n|o o |\n|ooo |\n|o o |\n|o o |\n|    |\n", // A
    "|oo  |\n|o o |\n|oo  |\n|o o |\n|oo  |\n|    |\n", // B
    "| oo |\n|o   |\n|o   |\n|o   |\n| oo |\n|    |\n", // C
    "|oo  |\n|o o |\n|o o |\n|o o |\n|oo  |\n|    |\n", // D
    "|ooo |\n|o   |\n|ooo |\n|o   |\n|ooo |\n|    |\n", // E
    "|ooo |\n|o   |\n|ooo |\n|o   |\n|o   |\n|    |\n", // F
    "| oo |\n|o   |\n|ooo |\n|o o |\n| oo |\n|    |\n", // G
    "|o o |\n|o o |\n|ooo |\n|o o |\n|o o |\n|    |\n", // H
    "|ooo |\n| o  |\n| o  |\n| o  |\n|ooo |\n|    |\n", // I
    "|  o |\n|  o |\n|  o |\n|o o |\n| o  |\n|    |\n", // J
    "|o o |\n|o o |\n|oo  |\n|o o |\n|o o |\n|    |\n", // K
    "|o   |\n|o   |\n|o   |\n|o   |\n|ooo |\n|    |\n", // L
    "|o o |\n|ooo |\n|ooo |\n|o o |\n|o o |\n|    |\n", // M
    "|o o |\n|ooo |\n|ooo |\n|ooo |\n|o o |\n|    |\n", // N
    "| o  |\n|o o |\n|o o |\n|o o |\n| o  |\n|    |\n", // O
    "|oo  |\n|o o |\n|oo  |\n|o   |\n|o   |\n|    |\n", // P
    "| o  |\n|o o |\n|o o |\n|ooo |\n| oo |\n|    |\n", // Q
    "|oo  |\n|o o |\n|ooo |\n|oo  |\n|o o |\n|    |\n", // R
    "| oo |\n|o   |\n| o  |\n|  o |\n|oo  |\n|    |\n", // S
    "|ooo |\n| o  |\n| o  |\n| o  |\n| o  |\n|    |\n", // T
    "|o o |\n|o o |\n|o o |\n|o o |\n| oo |\n|    |\n", // U
    "|o o |\n|o o |\n|o o |\n| o  |\n| o  |\n|    |\n", // V
    "|o o |\n|o o |\n|ooo |\n|ooo |\n|o o |\n|    |\n", // W
    "|o o |\n|o o |\n| o  |\n|o o |\n|o o |\n|    |\n", // X
    "|o o |\n|o o |\n| o  |\n| o  |\n| o  |\n|    |\n", // Y
    "|ooo |\n|  o |\n| o  |\n|o   |\n|ooo |\n|    |\n", // Z
    "|    |\n|    |\n|    |\n|    |\n|    |\n|    |\n", // SPACE
};

const all_letters: [37]Metatile23 = blk: {
    @setEvalBranchQuota(1000000);
    var result: [37]Metatile23 = undefined;
    for (0..37) |i| {
        result[i] = parseMt23(font_strings[i]);
    }
    break :blk result;
};

// ─── VRAM-buffered metatile draw ───

fn drawMetatile23(nmt: Nametable, x: u8, y: u8, tile: Metatile23) void {
    @setRuntimeSafety(false);
    const idx: usize = VRAM_INDEX;
    const nmt_byte: u16 = @intFromEnum(nmt);
    const ppuaddr_left: u16 = 0x2000 | (nmt_byte << 8) | (@as(u16, y) << 5 | @as(u16, x));
    const ppuaddr_right: u16 = ppuaddr_left + 1;
    VRAM_BUF[idx + 0] = @as(u8, @truncate(ppuaddr_left >> 8)) | NT_UPD_VERT;
    VRAM_BUF[idx + 1] = @as(u8, @truncate(ppuaddr_left));
    VRAM_BUF[idx + 6] = @as(u8, @truncate(ppuaddr_right >> 8)) | NT_UPD_VERT;
    VRAM_BUF[idx + 7] = @as(u8, @truncate(ppuaddr_right));
    VRAM_BUF[idx + 2] = 3;
    VRAM_BUF[idx + 8] = 3;
    VRAM_BUF[idx + 3] = tile.top_top >> 4;
    VRAM_BUF[idx + 9] = tile.top_top & 0x0F;
    VRAM_BUF[idx + 4] = tile.top_bot >> 4;
    VRAM_BUF[idx + 10] = tile.top_bot & 0x0F;
    VRAM_BUF[idx + 5] = tile.bot_top >> 4;
    VRAM_BUF[idx + 11] = tile.bot_top & 0x0F;
    VRAM_BUF[idx + 12] = 0xFF;
    VRAM_INDEX +%= 12;
}

fn charToLetter(c: u8) u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'A' and c <= 'Z') return c - 'A' + 10;
    if (c >= 'a' and c <= 'z') return c - 'a' + 10;
    return 36; // SPACE
}

// Renders ASCII text as 2×3-tile metatile glyphs to the VRAM buffer.
// SKIP_DRAWING_SPACE=true: spaces are skipped but advance by 1 tile (HALF_SIZE_SPACE=true).
fn renderString(nmt: Nametable, start_x: u8, start_y: u8, text: []const u8) void {
    var x: u8 = start_x;
    var y: u8 = start_y;
    for (text) |ch| {
        const letter = charToLetter(ch);
        if (letter != 36) {
            drawMetatile23(nmt, x, y, all_letters[letter]);
        }
        x +%= if (letter == 36) 1 else 2;
        if (x >= 31) {
            x = 0;
            y +%= 3;
        }
        if (VRAM_INDEX > (128 - 14)) {
            nesdoug.flush_vram_update2();
        }
    }
    NAME_UPD_ENABLE = 1;
}

// ─── player physics (fixed-point 8.8) ───
// Fu8_8: u16 raw; integer part = val >> 8
// Fs8_8: i16 raw; integer part = @as(i8, @truncate(val >> 8))

const VELOCITY_PERFRAME: i16 = 38; // 0.15 × 256
const SPEED_LIMIT: i16 = 640; // 2.5  × 256
const BRAKING: i16 = 89; // 0.35 × 256
const JUMP_MOMENTUM: i16 = 896; // 3.5  × 256
const GRAVITY: i16 = 102; // 0.40 × 256
const GRAVITY_LIMIT: i16 = 1024; // 4.0  × 256
const MIN_AIR_TIME: u8 = 5;
const MAX_AIR_TIME: u8 = 12;
const FLOOR_FP: u16 = 200 << 8; // y=200 as Fu8_8

const PlayerState = enum(u8) { Grounded, Rising, Falling };

// Metasprite data: [x_off, y_off, tile, attr, ...] terminated by 0x80
const frame0 = [_]i8{
    -4, -11, 0x0f, 0,
    0,  3,   0x06, 0,
    -2, -4,  0x05, 0,
    1,  -5,  0x06, 0,
    -9, -5,  0x09, 0,
    -7, 3,   0x09, 0,
    -128, // terminator
};
const frame1 = [_]i8{
    -4,  -11, 0x0f, 0,
    0,   3,   0x06, 0,
    -2,  -4,  0x05, 0,
    2,   -6,  0x06, @as(i8, @bitCast(OAM_FLIP_V)),
    -10, -6,  0x09, @as(i8, @bitCast(OAM_FLIP_V)),
    -7,  3,   0x09, 0,
    -128, // terminator
};
const frames = [2]*const anyopaque{ &frame0, &frame1 };

const Player = struct {
    x: u16 = 120 << 8, // Fu8_8
    y: u16 = 200 << 8, // Fu8_8
    vel_x: i16 = 0, // Fs8_8
    vel_y: i16 = 0, // Fs8_8
    state: PlayerState = .Grounded,
    jump_timer: u8 = 0,
    released_jump: bool = false,
    frame: u8 = 0,
    animation_count: u8 = 0,
};

var player = Player{};

fn updatePlayer() void {
    @setRuntimeSafety(false);
    const input = neslib.pad_state(0);

    // Horizontal movement with acceleration and speed limit
    if ((input & PAD_LEFT) != 0 and player.vel_x > -SPEED_LIMIT) {
        player.vel_x -%= VELOCITY_PERFRAME;
    } else if ((input & PAD_RIGHT) != 0 and player.vel_x < SPEED_LIMIT) {
        player.vel_x +%= VELOCITY_PERFRAME;
    } else {
        // Braking
        if (player.vel_x > 0) {
            player.vel_x = @max(player.vel_x -% BRAKING, 0);
        } else if (player.vel_x < 0) {
            player.vel_x = @min(player.vel_x +% BRAKING, 0);
        }
    }
    player.x +%= @as(u16, @bitCast(player.vel_x));

    // Walking animation
    if ((input & (PAD_LEFT | PAD_RIGHT)) != 0) {
        player.animation_count +%= 1;
        if ((player.animation_count & 0x0F) == 0)
            player.frame = (player.frame +% 1) & 1;
    } else {
        player.frame = 0;
        player.animation_count = 0;
    }

    // Jump initiation
    player.jump_timer +%= 1;
    if ((input & PAD_A) != 0 and player.state == .Grounded and player.released_jump) {
        player.state = .Rising;
        player.vel_y = -JUMP_MOMENTUM;
        player.jump_timer = 0;
        player.released_jump = false;
    }

    // Jump / fall state machine
    if (player.state == .Rising) {
        if (player.jump_timer > MIN_AIR_TIME and player.released_jump) {
            player.state = .Falling;
        } else if (player.jump_timer >= MAX_AIR_TIME) {
            player.state = .Falling;
        }
    } else if (player.state == .Falling and player.vel_y < GRAVITY_LIMIT) {
        player.vel_y +%= GRAVITY;
    }

    if ((input & PAD_A) == 0 and !player.released_jump)
        player.released_jump = true;

    // While airborne, force arms-up animation frame
    if (player.state != .Grounded)
        player.frame = 1;

    // Apply Y velocity; floor at y=200
    player.y +%= @as(u16, @bitCast(player.vel_y));
    if (player.y > FLOOR_FP) {
        player.y = FLOOR_FP;
        player.vel_y = 0;
        player.state = .Grounded;
    }

    // Draw metasprite
    const px: u8 = @truncate(player.x >> 8);
    const py: u8 = @truncate(player.y >> 8);
    neslib.oam_meta_spr(px, py, frames[player.frame]);
}

// ─── view / scroll ───

var scroll_y: u8 = 0;
var direction: i8 = 1;
var scroll_frame_count: u8 = 0;
var show_text_view: bool = true;

fn updateTextView() void {
    neslib.scroll(0, 0);
}

fn updateScrollingView() void {
    @setRuntimeSafety(false);
    scroll_frame_count = (scroll_frame_count +% 1) & 0x1F;
    if (scroll_frame_count == 0) direction = -direction;
    scroll_y +%= @as(u8, @bitCast(direction));
    // skip 240-255 range to avoid rendering the attribute table
    if (scroll_y >= 240)
        scroll_y = if (direction > 0) 0 else 239;
    nesdoug.set_scroll_x(0x100);
    nesdoug.set_scroll_y(scroll_y);
}

fn updateView() void {
    const input = nesdoug.get_pad_new(0);
    if ((input & PAD_SELECT) != 0) show_text_view = !show_text_view;
    if (show_text_view) updateTextView() else updateScrollingView();
}

// ─── entry point ───

pub export fn main() callconv(.c) void {
    nesdoug.set_vram_buffer();
    neslib.ppu_off();
    neslib.oam_clear();
    neslib.oam_size(0);
    neslib.pal_all(@ptrCast(&palette));
    neslib.scroll(0, 0);

    // Load default background into nametable B (direct write, PPU off)
    neslib.vram_adr(NAMETABLE_B);
    neslib.vram_unrle(@ptrCast(nametable_rle.ptr));

    // Buffer text glyphs into nametable A (flushed on first NMI after ppu_on_all)
    renderString(.A, 1, 1, "THE QUICK");
    renderString(.A, 1, 4, "BROWN FOX");
    renderString(.A, 1, 7, "JUMPS OVER");
    renderString(.A, 1, 10, "THE LAZY DOG");
    renderString(.A, 1, 14, "PUSH SELECT");
    renderString(.A, 1, 17, "TO SWITCH VIEW");

    neslib.ppu_on_all();

    while (true) {
        _ = neslib.pad_poll(0);
        neslib.oam_clear();
        updateView();
        updatePlayer();
        neslib.ppu_wait_nmi();
    }
}
