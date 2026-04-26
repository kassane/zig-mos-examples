// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! MEGA65 VICIV colour test.
//! Sets screen colour to bubblegum (0x1E) and cycles border colour forever.
//! VICIV base: 0xD000; bordercol at +0x20, screencol at +0x21.

const VICIV_BORDERCOL: *volatile u8 = @ptrFromInt(0xD020);
const VICIV_SCREENCOL: *volatile u8 = @ptrFromInt(0xD021);

export fn main() void {
    VICIV_SCREENCOL.* = 0x1E; // COLOR_BUBBLEGUM
    while (true) {
        VICIV_BORDERCOL.* +%= 1;
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
