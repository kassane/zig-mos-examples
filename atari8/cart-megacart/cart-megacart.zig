// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari 8-bit MegaCart color-cycle demo.
//! Cycles COLBK through all GTIA hues each frame, synced to ANTIC VCOUNT.
//! MegaCart bank 0 is selected by default at cold start via tail0.s stub.
pub const panic = @import("mos_panic");

const gtia = @import("gtia");

const GTIA: *volatile gtia.struct___gtia_write = @ptrFromInt(0xD000);
const VCOUNT: *volatile u8 = @ptrFromInt(0xD40B);

fn waitVblank() void {
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
