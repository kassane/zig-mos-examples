// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES LoROM hello: fills the backdrop with Zig orange and spins forever.

const hw = @import("snes");
comptime {
    _ = @import("snes_header");
}

pub fn main() void {
    // Force blank + brightness 0 while touching CGRAM.
    hw.INIDISP.* = 0x80;

    // Disable NMI and IRQ.
    hw.NMITIMEN.* = 0x00;

    // Write backdrop colour to CGRAM palette 0, entry 0.
    // Zig orange: R=31 G=14 B=2  →  15-bit BGR $09DF
    hw.CGADD.* = 0x00;
    const c = hw.color(31, 14, 2);
    hw.CGDATA.* = @truncate(c);
    hw.CGDATA.* = @truncate(c >> 8);

    // Turn off force-blank, full brightness.
    hw.INIDISP.* = 0x0f;

    while (true) {}
}
