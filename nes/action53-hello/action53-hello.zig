// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
pub const panic = @import("mos_panic");
const neslib = @import("neslib");
const mapper = @import("mapper");

const palette = [_]u8{
    0x1A, 0x00, 0x10, 0x20, // backdrop dark green, bg colours
    0x1A, 0x00, 0x10, 0x20,
    0x1A, 0x00, 0x10, 0x20,
    0x1A, 0x00, 0x10, 0x20,
    0x1A, 0x00, 0x10, 0x20, // sprite colours
    0x1A, 0x00, 0x10, 0x20,
    0x1A, 0x00, 0x10, 0x20,
    0x1A, 0x00, 0x10, 0x20,
};

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bright(4);
    neslib.pal_all(&palette);
    neslib.ppu_on_all();
    while (true) neslib.ppu_wait_nmi();
}
