// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES backdrop color-cycle: rotates the background through a full colour
// wheel (192 steps of ~1.875° each) by updating CGRAM palette entry 0 every
// vblank. Uses HVBJOY polling — no NMI handler required.

const sneslib = @import("sneslib");
comptime {
    _ = @import("snes_header");
}

/// Convert a phase value (0–191) to a 15-bit BGR colour wheel value.
/// The wheel passes through red → yellow → green → cyan → blue → magenta.
fn colorWheel(phase: u8) u16 {
    const p = phase % 192;
    const third: u8 = p / 32; // 0-5, one third of the wheel per segment
    const frac: u5 = @truncate(p % 32); // 0-31, position within segment
    const inv: u5 = @truncate(31 - @as(u8, frac));

    const r: u5 = switch (third) {
        0 => 31,
        1 => inv,
        2 => 0,
        3 => 0,
        4 => frac,
        5 => 31,
        else => 31,
    };
    const g: u5 = switch (third) {
        0 => frac,
        1 => 31,
        2 => 31,
        3 => inv,
        4 => 0,
        5 => 0,
        else => 0,
    };
    const b: u5 = switch (third) {
        0 => 0,
        1 => 0,
        2 => frac,
        3 => 31,
        4 => 31,
        5 => inv,
        else => 0,
    };
    return sneslib.color(r, g, b);
}

pub fn main() void {
    sneslib.ppu_off();
    sneslib.cgram_set(0, 0); // black
    sneslib.ppu_on();

    var phase: u8 = 0;
    while (true) {
        sneslib.wait_vblank();
        sneslib.cgram_set(0, colorWheel(phase));
        phase +%= 1;
        if (phase >= 192) phase = 0;
    }
}
