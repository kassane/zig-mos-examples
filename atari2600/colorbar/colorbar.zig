// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Atari 2600 4K color-bar demo.
//! Each frame the background color cycles through the TIA palette.
//! The default frameloop.c handles VSYNC/VBLANK timing; we only set COLUBK.
pub const panic = @import("mos_panic");

const vcs = @import("vcslib");

// TIA.COLUBK is at offset 9 from TIA base 0x0000 (volatile struct __tia).
// translate-c cannot lower the volatile pointer-cast macro, so we use a
// raw MMIO pointer here instead.
const COLUBK: *volatile u8 = @ptrFromInt(0x0009);

export fn main() void {
    var color: u8 = 0;
    while (true) {
        vcs.kernel_1(); // VSYNC + vblank timer setup
        vcs.kernel_2(); // wait for vblank, enable beam, start kernel timer
        COLUBK.* = color;
        vcs.kernel_3(); // wait for kernel timer, disable beam, overscan timer
        vcs.kernel_4(); // wait for overscan timer
        color +%= 2;
    }
}
