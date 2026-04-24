// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari 2600 3E mapper color-bar demo.
//! Identical to the 4K colorbar — the 3E mapper provides banked ROM
//! but the kernel loop and TIA usage are the same.
const vcs = @import("vcslib");

const COLUBK: *volatile u8 = @ptrFromInt(0x0009);

export fn main() void {
    var color: u8 = 0;
    while (true) {
        vcs.kernel_1();
        vcs.kernel_2();
        COLUBK.* = color;
        vcs.kernel_3();
        vcs.kernel_4();
        color +%= 2;
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
