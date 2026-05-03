// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES convenience library: PPU, VRAM, CGRAM, scroll, joypad, and video-effect helpers.

const hw = @import("snes");

/// Re-export color() from hardware.zig.
pub const color = hw.color;

// ---------------------------------------------------------------------------
// VBlank / NMI
// ---------------------------------------------------------------------------

/// VBlank flag set by the NMI handler each vertical blank; cleared by wait_vblank().
pub export var vblank_flag: u16 = 0;

// ---------------------------------------------------------------------------
// Joypad — auto-read buffers updated by the NMI handler each VBlank.
// Layout: index 0 = pad 1, index 1 = pad 2.
// Bit format (16-bit): JOY1H<<8 | JOY1L  (matches $4218/$4219 byte order).
// ---------------------------------------------------------------------------

/// Currently-held buttons (all frames while held).
pub export var pad_keys: [2]u16 = .{ 0, 0 };
/// Buttons held last frame (used for transition detection).
pub export var pad_keysold: [2]u16 = .{ 0, 0 };
/// Buttons newly pressed this frame (0→1 transitions only).
pub export var pad_keysdown: [2]u16 = .{ 0, 0 };

pub const KEY_B = @as(u16, 0x8000);
pub const KEY_Y = @as(u16, 0x4000);
pub const KEY_SELECT = @as(u16, 0x2000);
pub const KEY_START = @as(u16, 0x1000);
pub const KEY_UP = @as(u16, 0x0800);
pub const KEY_DOWN = @as(u16, 0x0400);
pub const KEY_LEFT = @as(u16, 0x0200);
pub const KEY_RIGHT = @as(u16, 0x0100);
pub const KEY_A = @as(u16, 0x0080);
pub const KEY_X = @as(u16, 0x0040);
pub const KEY_L = @as(u16, 0x0020);
pub const KEY_R = @as(u16, 0x0010);

/// Returns true if ALL of `buttons` are currently held on pad `pad` (0 or 1).
pub fn held(pad: u1, buttons: u16) bool {
    return pad_keys[pad] & buttons == buttons;
}

/// Returns true if ALL of `buttons` were just pressed this frame on pad `pad`.
pub fn pressed(pad: u1, buttons: u16) bool {
    return pad_keysdown[pad] & buttons == buttons;
}

// ---------------------------------------------------------------------------
// Display
// ---------------------------------------------------------------------------

/// Tracked brightness (0–15). $2100 (INIDISP) is write-only on real hardware.
var _brightness: u8 = 0;

/// Disable display (force blank) and turn off NMI/IRQ.
pub fn ppu_off() void {
    hw.INIDISP.* = 0x80;
    hw.NMITIMEN.* = 0x00;
}

/// Enable display at full brightness (force-blank off).
pub fn ppu_on() void {
    _brightness = 15;
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
    hw.A1B(0).* = @truncate(@as(u32, @intCast(ptr)) >> 16);
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
    hw.A1B(0).* = @truncate(@as(u32, @intCast(ptr)) >> 16);
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
    hw.A1B(0).* = @truncate(@as(u32, @intCast(ptr)) >> 16);
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

// ---------------------------------------------------------------------------
// Brightness / fades
// ---------------------------------------------------------------------------

/// Set display brightness (0 = off/blank, 15 = full). Updates the write-only INIDISP shadow.
pub fn set_brightness(level: u4) void {
    _brightness = level;
    hw.INIDISP.* = level;
}

/// Decrease brightness by one step. Returns true when it reaches 0 (fade-out complete).
pub fn fade_out_step() bool {
    if (_brightness == 0) return true;
    _brightness -= 1;
    hw.INIDISP.* = _brightness;
    return _brightness == 0;
}

/// Increase brightness by one step. Returns true when it reaches 15 (fade-in complete).
pub fn fade_in_step() bool {
    if (_brightness == 15) return true;
    _brightness += 1;
    hw.INIDISP.* = _brightness;
    return _brightness == 15;
}

// ---------------------------------------------------------------------------
// Video effects
// ---------------------------------------------------------------------------

/// Enable mosaic: `size` = pixel enlargement 0–15, `bg_mask` = BG enable bits 0–3.
pub fn set_mosaic(size: u4, bg_mask: u4) void {
    hw.MOSAIC.* = (@as(u8, size) << 4) | @as(u8, bg_mask);
}

/// Disable mosaic on all BGs.
pub fn mosaic_off() void {
    hw.MOSAIC.* = 0x00;
}

/// Configure colour math registers: `cgwsel` → $2130, `cgadsub` → $2131.
pub fn set_color_math(cgwsel: u8, cgadsub: u8) void {
    hw.CGWSEL.* = cgwsel;
    hw.CGADSUB.* = cgadsub;
}

/// OR multiple button constants together at comptime.
/// Usage: `sneslib.buttonMask(.{sneslib.KEY_A, sneslib.KEY_B})`
pub fn buttonMask(comptime btns: anytype) u16 {
    comptime var mask: u16 = 0;
    inline for (btns) |b| mask |= b;
    return mask;
}
