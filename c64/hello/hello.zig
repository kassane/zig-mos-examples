// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 VIC-II border and background colour cycling demo.
//! Uses the translated c64.h module for VIC struct type and color constants.
pub const panic = @import("mos_panic");

const std = @import("std");
const c64 = @import("c64");

const VIC: *volatile c64.__vic2 = @ptrFromInt(0xD000);

export fn main() void {
    VIC.unnamed_2.unnamed_0.bgcolor0 = c64.COLOR_BLACK;
    _ = std.c.printf("Hello Zig!\n");
    while (true) {
        VIC.bordercolor +%= 1;
    }
}
