// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari 8-bit DOS hello-world.
//! Uses the atari8-common libc putchar via std.c.printf.
const std = @import("std");

export fn main() void {
    _ = std.c.printf("Hello from Atari 8-bit DOS!\n");
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = std.c.printf("PANIC: %s\n", msg.ptr);
    while (true) {}
}
