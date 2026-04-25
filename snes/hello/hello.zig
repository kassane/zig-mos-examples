// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES LoROM hello: fills the backdrop with Zig orange and spins forever.
//
// Hardware registers (bank $00, 8-bit I/O):
//   $2100  INIDISP  — display control: bit7=force-blank, bits3-0=brightness (0–15)
//   $2121  CGADD    — CGRAM address (palette index)
//   $2122  CGDATA   — CGRAM data: two 8-bit writes per 15-bit BGR colour entry
//   $4200  NMITIMEN — NMI/timer/IRQ enable

const INIDISP = @as(*volatile u8, @ptrFromInt(0x2100));
const CGADD = @as(*volatile u8, @ptrFromInt(0x2121));
const CGDATA = @as(*volatile u8, @ptrFromInt(0x2122));
const NMITIMEN = @as(*volatile u8, @ptrFromInt(0x4200));

// Build a 15-bit BGR colour word (SNES format: 0bbbbbgggggrrrrr).
fn snesColor(r: u5, g: u5, b: u5) u16 {
    return @as(u16, r) | (@as(u16, g) << 5) | (@as(u16, b) << 10);
}

pub fn main() void {
    // Force blank (bit 7) + brightness 0 while we touch VRAM/CGRAM.
    INIDISP.* = 0x80;

    // Disable NMI and IRQ.
    NMITIMEN.* = 0x00;

    // Write backdrop colour to CGRAM palette 0, entry 0.
    // Zig orange: R=31 G=14 B=2  →  0x04ff  (15-bit BGR)
    CGADD.* = 0x00;
    const color = snesColor(31, 14, 2);
    CGDATA.* = @truncate(color); // low byte first
    CGDATA.* = @truncate(color >> 8); // high byte second

    // Turn off force-blank and set full brightness (15).
    INIDISP.* = 0x0f;

    // Halt — the SNES backdrop is now visible.
    while (true) {}
}
