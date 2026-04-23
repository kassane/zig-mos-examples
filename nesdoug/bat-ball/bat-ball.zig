// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES bat-ball: bounce a ball off walls and bat; 3 lives before game over.
//! Port of CH05 from tony-cruise/ProgrammingGamesForTheNES.
//! Uses check_collision (nesdoug) for bat–ball detection, pad_poll (neslib) for input.
const neslib = @import("neslib");
const nesdoug = @import("nesdoug");

// check_collision requires the first 4 bytes of each object to be x, y, w, h.
const Obj = extern struct {
    x: u8,
    y: u8,
    w: u8,
    h: u8,
};

const BALL_W: u8 = 8;
const BALL_H: u8 = 8;
const BAT_W: u8 = 24;
const BAT_H: u8 = 8;
const BAT_Y: u8 = 200;

/// Combined bg + spr palette (32 bytes).
/// bg pal 0: black background.
/// spr pal 0: ball — white/orange/yellow.
/// spr pal 1: bat  — blue shades.
const all_palette: [32]u8 = .{
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x30, 0x16, 0x27,
    0x0f, 0x11, 0x21, 0x30,
    0x0f, 0x16, 0x27, 0x30,
    0x0f, 0x16, 0x27, 0x30,
};

var ball: Obj = .{ .x = 120, .y = 80, .w = BALL_W, .h = BALL_H };
var bat:  Obj = .{ .x = 112, .y = BAT_Y, .w = BAT_W, .h = BAT_H };
var ball_dx: i8 = 1;
var ball_dy: i8 = 1;
var lives: u8 = 3;

fn resetBall() void {
    ball.x = 120;
    ball.y = 80;
    ball_dx = 1;
    ball_dy = 1;
    bat.x = 112;
}

export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_all(&all_palette);
    neslib.bank_spr(0);
    neslib.ppu_on_all();

    while (lives > 0) {
        neslib.ppu_wait_nmi();

        const pad = neslib.pad_poll(0);
        if (pad & 0x02 != 0 and bat.x > 8)   bat.x -= 2; // PAD_LEFT
        if (pad & 0x01 != 0 and bat.x < 224) bat.x += 2; // PAD_RIGHT

        ball.x = @intCast(@as(i16, ball.x) + ball_dx);
        ball.y = @intCast(@as(i16, ball.y) + ball_dy);

        if (ball.x <= 8)   { ball.x = 8;   ball_dx =  1; }
        if (ball.x >= 248) { ball.x = 248;  ball_dx = -1; }
        if (ball.y <= 8)   { ball.y = 8;   ball_dy =  1; }

        if (nesdoug.check_collision(@ptrCast(&ball), @ptrCast(&bat)) != 0) {
            ball_dy = -1;
            ball.y = BAT_Y - BALL_H;
        }

        // Ball past the bottom → lose a life.
        if (ball.y >= 232) {
            lives -= 1;
            if (lives > 0) resetBall();
        }

        neslib.oam_clear();
        neslib.oam_spr(ball.x,       ball.y, 'O', 0x00);
        neslib.oam_spr(bat.x,        bat.y,  '=', 0x01);
        neslib.oam_spr(bat.x + 8,    bat.y,  '=', 0x01);
        neslib.oam_spr(bat.x + 16,   bat.y,  '=', 0x01);
    }

    // Game over — freeze.
    while (true) {}
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
