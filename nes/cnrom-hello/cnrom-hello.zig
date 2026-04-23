// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES CNROM mapper hello — solid background color using neslib.
const neslib = @import("neslib");

export fn main() void {
    // Wait for stable PPU then set a palette and enable rendering.
    neslib.ppu_off();
    // Blue background: color 0x11 (NES light blue)
    const bg_pal = [_]u8{ 0x0F, 0x11, 0x21, 0x31 };
    neslib.pal_bg(&bg_pal);
    neslib.ppu_on_bg();
    while (true) {}
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
