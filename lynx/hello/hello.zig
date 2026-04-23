// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari Lynx BLL palette cycling demo.
//! Uses the translated lynx.h module for MIKEY struct type.
//! The MIKEY palette is at 0xFDA0 (32 bytes).

const lynx = @import("lynx");

const MIKEY: *volatile lynx.struct___mikey = @ptrFromInt(0xFD00);

export fn main() void {
    var phase: u8 = 0;
    while (true) {
        var i: u8 = 0;
        while (i < 32) : (i += 1) {
            MIKEY.palette[i] = phase +% i;
        }
        phase +%= 1;
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
