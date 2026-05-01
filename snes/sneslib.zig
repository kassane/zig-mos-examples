// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES convenience library: common PPU, VRAM, CGRAM, and scroll helpers.

const hw = @import("snes");

/// Re-export color() from hardware.zig.
pub const color = hw.color;

/// VBlank flag set by the NMI handler each vertical blank; cleared by wait_vblank().
pub export var vblank_flag: u16 = 0;

/// Disable display (force blank) and turn off NMI/IRQ.
pub fn ppu_off() void {
    hw.INIDISP.* = 0x80;
    hw.NMITIMEN.* = 0x00;
}

/// Enable display at full brightness (force-blank off).
pub fn ppu_on() void {
    hw.INIDISP.* = 0x0f;
}

/// Zero all PPU write registers $2100–$212F then double-write the scroll latches.
/// Call during force-blank (after ppu_off()) before first ppu_on().
pub fn ppu_init() void {
    var addr: u16 = 0x2100;
    while (addr <= 0x212f) : (addr += 1) {
        @as(*volatile u8, @ptrFromInt(addr)).* = 0;
    }
    // Scroll registers ($210D–$2114) have an internal write-twice latch;
    // the loop above writes them once, so call bg_scroll_zero() for the second write.
    bg_scroll_zero();
}

/// Wait for the next VBlank via the NMI handler.
/// Enables NMI + joypad auto-read, clears vblank_flag, then halts with `wai`
/// until the NMI fires and the handler sets vblank_flag = 1.
pub fn wait_vblank() void {
    hw.NMITIMEN.* = 0x81; // NMI enable + joypad auto-read
    vblank_flag = 0;
    asm volatile ("wai");
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

/// GP-DMA: copy `size` bytes from `src` to VRAM starting at word address `vram_addr`.
/// Caller must ensure force-blank is active (call ppu_off() first).
pub fn dma_copy_vram(src: [*]const u8, vram_addr: u16, size: u16) void {
    hw.VMAIN.* = 0x80; // increment VRAM address by 1 word after high-byte write
    hw.VMADDL.* = @truncate(vram_addr);
    hw.VMADDH.* = @truncate(vram_addr >> 8);
    const ptr = @intFromPtr(src);
    hw.DMAP(0).* = 0x01; // CPU→B-bus, auto-increment A-bus, 2-reg alternating (VMDATAL/VMDATAH)
    hw.BBAD(0).* = 0x18; // B-bus destination = $2118 (VMDATAL)
    hw.A1TL(0).* = @truncate(ptr);
    hw.A1TH(0).* = @truncate(ptr >> 8);
    hw.A1B(0).* = @truncate(ptr >> 16);
    hw.DASL(0).* = @truncate(size);
    hw.DASH(0).* = @truncate(size >> 8);
    hw.MDMAEN.* = 0x01;
}

/// GP-DMA: copy `size` bytes from `src` into CGRAM starting at byte address `cgram_addr`.
/// Caller must ensure force-blank is active (call ppu_off() first).
pub fn dma_copy_cgram(src: [*]const u8, cgram_addr: u8, size: u16) void {
    hw.CGADD.* = cgram_addr;
    const ptr = @intFromPtr(src);
    hw.DMAP(0).* = 0x00; // CPU→B-bus, auto-increment A-bus, 1-byte
    hw.BBAD(0).* = 0x22; // B-bus destination = $2122 (CGDATA)
    hw.A1TL(0).* = @truncate(ptr);
    hw.A1TH(0).* = @truncate(ptr >> 8);
    hw.A1B(0).* = @truncate(ptr >> 16);
    hw.DASL(0).* = @truncate(size);
    hw.DASH(0).* = @truncate(size >> 8);
    hw.MDMAEN.* = 0x01;
}

/// GP-DMA: copy `size` bytes from `src` into OAM starting at byte offset 0.
/// Caller must ensure force-blank is active (call ppu_off() first).
pub fn dma_copy_oam(src: [*]const u8, size: u16) void {
    hw.OAMADDL.* = 0x00;
    hw.OAMADDH.* = 0x00;
    const ptr = @intFromPtr(src);
    hw.DMAP(0).* = 0x00; // CPU→B-bus, auto-increment A-bus, 1-byte
    hw.BBAD(0).* = 0x04; // B-bus destination = $2104 (OAMDATA)
    hw.A1TL(0).* = @truncate(ptr);
    hw.A1TH(0).* = @truncate(ptr >> 8);
    hw.A1B(0).* = @truncate(ptr >> 16);
    hw.DASL(0).* = @truncate(size);
    hw.DASH(0).* = @truncate(size >> 8);
    hw.MDMAEN.* = 0x01;
}

/// Write a 15-bit BGR colour to CGRAM at palette byte index `index`.
pub fn cgram_set(index: u8, c: u16) void {
    hw.CGADD.* = index;
    hw.CGDATA.* = @truncate(c);
    hw.CGDATA.* = @truncate(c >> 8);
}

/// Zero-initialize all BG scroll register pairs (write-twice: low then high).
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
