// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari 8-bit standard cartridge background color cycling demo.
//! Uses the translated _gtia.h module for the GTIA write struct.
//! Cycles COLBK through all GTIA hues each frame, synced to ANTIC VCOUNT.

const gtia = @import("gtia");

const GTIA: *volatile gtia.struct___gtia_write = @ptrFromInt(0xD000);
// ANTIC read-only registers at 0xD400; VCOUNT is at offset 0x0B.
const VCOUNT: *volatile u8 = @ptrFromInt(0xD40B);

fn waitVblank() void {
    // Wait until VCOUNT drops back to top-of-frame (< 4 = near top).
    while (VCOUNT.* >= 4) {}
    while (VCOUNT.* < 4) {}
}

export fn main() void {
    var color: u8 = 0;
    while (true) {
        waitVblank();
        GTIA.colbk = color;
        color +%= 2;
    }
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
