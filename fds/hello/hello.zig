// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
pub const panic = @import("mos_panic");
const hw = @import("hardware");

// FDS runs from PRG-RAM at $6000; PPU is same as NES.

fn ppuWarmup() void {
    // Wait two full VBlanks for PPU to stabilize.
    _ = hw.PPUSTATUS.*;
    hw.ppuWaitVblank();
    hw.ppuWaitVblank();
}

pub export fn main() callconv(.c) void {
    ppuWarmup();

    // Disable rendering.
    hw.PPUCTRL.* = 0x00;
    hw.PPUMASK.* = 0x00;

    // Write backdrop colour $1A (dark green) to palette entry 0.
    hw.ppuSetAddr(0x3F00);
    hw.PPUDATA.* = 0x1A;

    // Enable rendering (backdrop only).
    hw.PPUCTRL.* = 0x00;
    hw.PPUMASK.* = hw.MASK_SHOW_BG;

    while (true) {}
}
