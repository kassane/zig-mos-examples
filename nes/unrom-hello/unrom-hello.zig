// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES UNROM mapper hello — solid background color using neslib.
const neslib = @import("neslib");

export fn main() void {
    neslib.ppu_off();
    const bg_pal = [_]u8{ 0x0F, 0x16, 0x27, 0x30 };
    neslib.pal_bg(&bg_pal);
    neslib.ppu_on_bg();
    while (true) {}
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
