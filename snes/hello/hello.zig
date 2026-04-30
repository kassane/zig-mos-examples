// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES LoROM hello: fills the backdrop with Zig orange and spins forever.

pub const panic = @import("mos_panic");

const sneslib = @import("sneslib");
comptime {
    _ = @import("snes_header");
}

pub fn main() void {
    sneslib.ppu_off();
    // Zig orange: R=31 G=14 B=2  →  15-bit BGR $09DF
    sneslib.cgram_set(0, sneslib.color(31, 14, 2));
    sneslib.ppu_on();
    while (true) {}
}
