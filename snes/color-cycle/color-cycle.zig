// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES backdrop color-cycle: rotates the background through a full colour
// wheel (192 steps of ~1.875° each) by updating CGRAM palette entry 0 every
// vblank. Uses HVBJOY polling — no NMI handler required.

const hw = @import("snes");
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
        0 => 31, // red full
        1 => inv, // red fading
        2 => 0,
        3 => 0,
        4 => frac, // red rising
        5 => 31,
        else => 31,
    };
    const g: u5 = switch (third) {
        0 => frac, // green rising
        1 => 31,
        2 => 31,
        3 => inv, // green fading
        4 => 0,
        5 => 0,
        else => 0,
    };
    const b: u5 = switch (third) {
        0 => 0,
        1 => 0,
        2 => frac, // blue rising
        3 => 31,
        4 => 31,
        5 => inv, // blue fading
        else => 0,
    };
    return hw.color(r, g, b);
}

/// Wait for vblank start by polling HVBJOY bit 7.
fn waitVblank() void {
    while (hw.HVBJOY.* & 0x80 != 0) {} // drain any current vblank
    while (hw.HVBJOY.* & 0x80 == 0) {} // wait for next vblank
}

pub fn main() void {
    hw.INIDISP.* = 0x80; // force blank while initialising
    hw.NMITIMEN.* = 0x00; // NMI/IRQ off; only HVBJOY polling used

    // Initialise CGRAM entry 0 to black.
    hw.CGADD.* = 0x00;
    hw.CGDATA.* = 0x00;
    hw.CGDATA.* = 0x00;

    hw.INIDISP.* = 0x0f; // full brightness, force-blank off

    var phase: u8 = 0;
    while (true) {
        waitVblank();

        // CGRAM writes are safe during vblank.
        const c = colorWheel(phase);
        hw.CGADD.* = 0x00;
        hw.CGDATA.* = @truncate(c);
        hw.CGDATA.* = @truncate(c >> 8);

        phase +%= 1;
        if (phase >= 192) phase = 0;
    }
}
