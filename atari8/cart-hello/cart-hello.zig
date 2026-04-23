// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari 8-bit standard cartridge hello example.
const std = @import("std");

export fn main() void {
    _ = std.c.printf("Hello from Atari 8-bit cartridge!\n");
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
