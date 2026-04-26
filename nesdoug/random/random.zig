// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES random demo: 64 sprites placed at random positions when Start is pressed,
//! then fall at three different speeds. Matches nesdoug 23_Random.
const neslib = @import("neslib");
const nesdoug = @import("nesdoug");

const palette_bg: [16]u8 = .{ 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30, 0x0f, 0x00, 0x10, 0x30 };
const palette_sp: [16]u8 = .{ 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28, 0x0f, 0x0f, 0x0f, 0x28 };

const PAD_START: u8 = 0x10;

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bg(&palette_bg);
    neslib.pal_spr(&palette_sp);
    neslib.bank_spr(1);
    neslib.vram_adr(neslib.NTADR_A(7, 14));
    neslib.vram_write("Press Start", 11);
    neslib.ppu_on_all();

    var spr_x: [64]u8 = undefined;
    var spr_y: [64]u8 = undefined;
    var start_pressed: bool = false;

    while (true) {
        neslib.ppu_wait_nmi();
        neslib.oam_clear();

        const pad1 = neslib.pad_poll(0);
        if (!start_pressed) {
            if (pad1 & PAD_START != 0) {
                start_pressed = true;
                nesdoug.seed_rng();
                for (&spr_x, &spr_y) |*x, *y| {
                    x.* = neslib.rand8();
                    y.* = neslib.rand8();
                }
            }
        } else {
            // Slow group (every other frame)
            var i: u8 = 0;
            while (i < 25) : (i += 1) {
                if (nesdoug.get_frame_count() & 1 != 0) spr_y[i] +%= 1;
                neslib.oam_spr(spr_x[i], spr_y[i], 0, 0);
            }
            // Normal group (1px/frame)
            while (i < 55) : (i += 1) {
                spr_y[i] +%= 1;
                neslib.oam_spr(spr_x[i], spr_y[i], 0, 0);
            }
            // Fast group (2px/frame)
            while (i < 64) : (i += 1) {
                spr_y[i] +%= 2;
                neslib.oam_spr(spr_x[i], spr_y[i], 0, 0);
            }
        }
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
