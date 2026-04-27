// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES convenience library: common PPU, VRAM, CGRAM, and scroll helpers.

const hw = @import("snes");

/// Re-export color() from hardware.zig.
pub const color = hw.color;

/// Disable display (force blank) and turn off NMI/IRQ.
pub fn ppu_off() void {
    hw.INIDISP.* = 0x80;
    hw.NMITIMEN.* = 0x00;
}

/// Enable display at full brightness (force-blank off).
pub fn ppu_on() void {
    hw.INIDISP.* = 0x0f;
}

/// Wait for the start of vertical blank by polling HVBJOY bit 7.
pub fn wait_vblank() void {
    while (hw.HVBJOY.* & 0x80 != 0) {}
    while (hw.HVBJOY.* & 0x80 == 0) {}
}

/// Set VRAM word address for subsequent VMDATAL/VMDATAH writes.
pub fn vram_set_addr(addr: u16) void {
    hw.VMADDL.* = @truncate(addr);
    hw.VMADDH.* = @truncate(addr >> 8);
}

/// Write one VRAM word (low byte then high byte).
/// Address auto-increments after VMDATAH write (requires VMAIN = 0x80).
pub fn vram_write(lo: u8, hi: u8) void {
    hw.VMDATAL.* = lo;
    hw.VMDATAH.* = hi;
}

/// Write a 15-bit BGR colour to CGRAM at palette byte index `index`.
pub fn cgram_set(index: u8, c: u16) void {
    hw.CGADD.* = index;
    hw.CGDATA.* = @truncate(c);
    hw.CGDATA.* = @truncate(c >> 8);
}

/// Zero-initialize all BG scroll register pairs (write-twice: low then high).
/// Must be called before enabling display — crt0.s does not initialize PPU registers.
pub fn bg_scroll_zero() void {
    hw.BG1HOFS.* = 0x00;
    hw.BG1HOFS.* = 0x00;
    hw.BG1VOFS.* = 0x00;
    hw.BG1VOFS.* = 0x00;
    hw.BG2HOFS.* = 0x00;
    hw.BG2HOFS.* = 0x00;
    hw.BG2VOFS.* = 0x00;
    hw.BG2VOFS.* = 0x00;
    hw.BG3HOFS.* = 0x00;
    hw.BG3HOFS.* = 0x00;
    hw.BG3VOFS.* = 0x00;
    hw.BG3VOFS.* = 0x00;
    hw.BG4HOFS.* = 0x00;
    hw.BG4HOFS.* = 0x00;
    hw.BG4VOFS.* = 0x00;
    hw.BG4VOFS.* = 0x00;
}
