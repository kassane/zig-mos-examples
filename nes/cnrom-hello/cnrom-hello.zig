// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES CNROM mapper hello — solid background colour, explicit CHR bank init.
//! CNROM (mapper 3) switches 8 KiB CHR ROM banks by writing to $8000-$FFFF.
//! Uses translated mapper.h (set_chr_bank / swap_chr_bank / split_chr_bank).
const neslib = @import("neslib");
const mapper = @import("mapper");

export fn main() void {
    neslib.ppu_off();
    // Select CHR bank 0 (Alpha.chr) before enabling rendering.
    mapper.set_chr_bank(0);
    // Blue background: NES palette 0x11 (light blue).
    const bg_pal = [_]u8{ 0x0F, 0x11, 0x21, 0x31 };
    neslib.pal_bg(&bg_pal);
    neslib.ppu_on_bg();
    while (true) {}
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
