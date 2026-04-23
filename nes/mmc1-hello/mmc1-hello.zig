// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES MMC1 mapper hello — solid background color using neslib.
const neslib = @import("neslib");

export fn main() void {
    neslib.ppu_off();
    const bg_pal = [_]u8{ 0x0F, 0x1A, 0x2A, 0x3A };
    neslib.pal_bg(&bg_pal);
    neslib.ppu_on_bg();
    while (true) {}
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
