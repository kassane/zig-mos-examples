// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES hello-world: writes "Hello Zig!" to the background nametable.
const neslib = @import("neslib");

/// One full BG palette (4 sub-palettes × 4 colours = 16 bytes).
/// Sub-palette 0: black background, three greys.
const bg_palette: [16]u8 = .{ 0x0f, 0x00, 0x10, 0x30 } ++ .{0x00} ** 12;

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bg(&bg_palette);
    neslib.vram_adr(neslib.NTADR_A(10, 14));
    for ("Hello Zig!") |c| neslib.vram_put(c);
    neslib.ppu_on_all();
    while (true) {}
}
