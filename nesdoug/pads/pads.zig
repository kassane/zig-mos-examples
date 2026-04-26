// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES controller demo: two metasprites (yellow P1, blue P2) with box collision.
//! Matches nesdoug 08_Pads: bank_spr(1), check_collision for AABB detection.
const neslib = @import("neslib");
const nesdoug = @import("nesdoug");

// Box used by check_collision: x, y, width-1, height-1 (top-left origin)
const BoxGuy = extern struct { x: u8, y: u8, width: u8, height: u8 };

const OAM_FLIP_H: u8 = 0x40;

// 16x16 yellow metasprite (palette 0)
const yellow_spr: []const u8 = &.{
    0,   0, 0x00, 0,
    0,   8, 0x10, 0,
    8,   0, 0x00, OAM_FLIP_H,
    8,   8, 0x10, OAM_FLIP_H,
    128,
};

// 16x16 blue metasprite (palette 1)
const blue_spr: []const u8 = &.{
    0,   0, 0x00, 1,
    0,   8, 0x10, 1,
    8,   0, 0x00, 1 | OAM_FLIP_H,
    8,   8, 0x10, 1 | OAM_FLIP_H,
    128,
};

const palette_bg: [16]u8 = .{ 0x00, 0x00, 0x10, 0x30, 0x00, 0x00, 0x10, 0x30, 0x00, 0x00, 0x10, 0x30, 0x00, 0x00, 0x10, 0x30 };
const palette_sp: [16]u8 = .{
    0x0f, 0x0f, 0x0f, 0x28, // yellow
    0x0f, 0x0f, 0x0f, 0x12, // blue
    0x0f, 0x0f, 0x0f, 0x28,
    0x0f, 0x0f, 0x0f, 0x28,
};

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bg(&palette_bg);
    neslib.pal_spr(&palette_sp);
    neslib.bank_spr(1);
    neslib.vram_adr(neslib.NTADR_A(7, 14));
    neslib.vram_write("Sprite Collisions", 17);
    neslib.ppu_on_all();

    var box1 = BoxGuy{ .x = 20, .y = 20, .width = 15, .height = 15 };
    var box2 = BoxGuy{ .x = 70, .y = 20, .width = 15, .height = 15 };

    while (true) {
        neslib.ppu_wait_nmi();

        const pad1 = neslib.pad_poll(0);
        const pad2 = neslib.pad_poll(1);

        if (pad1 & 0x02 != 0) box1.x -%= 1; // PAD_LEFT
        if (pad1 & 0x01 != 0) box1.x +%= 1; // PAD_RIGHT
        if (pad1 & 0x08 != 0) box1.y -%= 1; // PAD_UP
        if (pad1 & 0x04 != 0) box1.y +%= 1; // PAD_DOWN

        if (pad2 & 0x02 != 0) box2.x -%= 1;
        if (pad2 & 0x01 != 0) box2.x +%= 1;
        if (pad2 & 0x08 != 0) box2.y -%= 1;
        if (pad2 & 0x04 != 0) box2.y +%= 1;

        const hit = nesdoug.check_collision(@ptrCast(&box1), @ptrCast(&box2));
        neslib.pal_col(0, if (hit != 0) 0x30 else 0x00);

        neslib.oam_clear();
        neslib.oam_meta_spr(box1.x, box1.y, @ptrCast(yellow_spr.ptr));
        neslib.oam_meta_spr(box2.x, box2.y, @ptrCast(blue_spr.ptr));
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
