// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari 8-bit DOS hello-world.
//! Uses the atari8-common libc putchar via std.c.printf.
pub const panic = @import("mos_panic");

const std = @import("std");

export fn main() void {
    _ = std.c.printf("Hello from Atari 8-bit DOS!\n");
}
