// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari 5200 supercart color-cycle demo.
//! GTIA COLBK register at $C01A cycles background through all hues.
//! No CIO/stdio on 5200; uses direct hardware register writes.
pub const panic = @import("mos_panic");

const COLBK: *volatile u8 = @ptrFromInt(0xC01A);

export fn main() void {
    var color: u8 = 0;
    while (true) {
        COLBK.* = color;
        color +%= 2;
    }
}
