// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES hardware register definitions — 8-bit I/O, bank $00 ($2100–$437F).

fn reg(comptime addr: comptime_int) *volatile u8 {
    return @ptrFromInt(addr);
}

// ---- PPU: Display ----
pub const INIDISP = reg(0x2100); // bit7=force-blank, bits3-0=brightness (0–15)
pub const OBSEL = reg(0x2101); // OBJ size and base address
pub const OAMADDL = reg(0x2102); // OAM address low
pub const OAMADDH = reg(0x2103); // OAM address high + priority
pub const OAMDATA = reg(0x2104); // OAM data write

// ---- PPU: BG / Mode ----
pub const BGMODE = reg(0x2105); // BG mode and character size
pub const MOSAIC = reg(0x2106); // Screen pixelation
pub const BG1SC = reg(0x2107); // BG1 tilemap base + size
pub const BG2SC = reg(0x2108); // BG2 tilemap base + size
pub const BG3SC = reg(0x2109); // BG3 tilemap base + size
pub const BG4SC = reg(0x210a); // BG4 tilemap base + size
pub const BG12NBA = reg(0x210b); // BG1/BG2 tile data base addresses
pub const BG34NBA = reg(0x210c); // BG3/BG4 tile data base addresses

// ---- PPU: Scroll ----
pub const BG1HOFS = reg(0x210d);
pub const BG1VOFS = reg(0x210e);
pub const BG2HOFS = reg(0x210f);
pub const BG2VOFS = reg(0x2110);
pub const BG3HOFS = reg(0x2111);
pub const BG3VOFS = reg(0x2112);
pub const BG4HOFS = reg(0x2113);
pub const BG4VOFS = reg(0x2114);

// ---- PPU: VRAM ----
pub const VMAIN = reg(0x2115); // VRAM address increment mode
pub const VMADDL = reg(0x2116); // VRAM address low byte
pub const VMADDH = reg(0x2117); // VRAM address high byte
pub const VMDATAL = reg(0x2118); // VRAM data write low byte
pub const VMDATAH = reg(0x2119); // VRAM data write high byte

// ---- PPU: Mode 7 ----
pub const M7SEL = reg(0x211a); // Mode 7 settings (flip, repeat)
pub const M7A = reg(0x211b); // Mode 7 matrix A (write twice: low, high)
pub const M7B = reg(0x211c); // Mode 7 matrix B / multiplicand (write twice)
pub const M7C = reg(0x211d); // Mode 7 matrix C (write twice)
pub const M7D = reg(0x211e); // Mode 7 matrix D (write twice)
pub const M7X = reg(0x211f); // Mode 7 center X (write twice)
pub const M7Y = reg(0x2120); // Mode 7 center Y (write twice)

// ---- PPU: Palette (CGRAM) ----
pub const CGADD = reg(0x2121); // CGRAM byte address (palette index × 2)
pub const CGDATA = reg(0x2122); // CGRAM data write (two 8-bit writes per 15-bit BGR entry)

// ---- PPU: Window Masking ----
pub const W12SEL = reg(0x2123); // Window mask settings for BG1/BG2
pub const W34SEL = reg(0x2124); // Window mask settings for BG3/BG4
pub const WOBJSEL = reg(0x2125); // Window mask settings for OBJ and color window
pub const WH0 = reg(0x2126); // Window 1 left border
pub const WH1 = reg(0x2127); // Window 1 right border
pub const WH2 = reg(0x2128); // Window 2 left border
pub const WH3 = reg(0x2129); // Window 2 right border
pub const WBGLOG = reg(0x212a); // Window mask logic for BG1–BG4
pub const WOBJLOG = reg(0x212b); // Window mask logic for OBJ and color window

// ---- PPU: Layer enable ----
pub const TM = reg(0x212c); // Main screen layer enable
pub const TS = reg(0x212d); // Sub screen layer enable
pub const TMW = reg(0x212e); // Main screen window enable
pub const TSW = reg(0x212f); // Sub screen window enable

// ---- PPU: Color Math ----
pub const CGWSEL = reg(0x2130); // Color math control (clip/prevent, add/sub windows)
pub const CGADSUB = reg(0x2131); // Color math add/subtract layer select
pub const COLDATA = reg(0x2132); // Fixed color data (B/G/R + intensity)

// ---- PPU: Multiplication result (read) ----
pub const MPYL = reg(0x2134); // Signed multiply result low   (M7A × M7B)
pub const MPYM = reg(0x2135); // Signed multiply result middle
pub const MPYH = reg(0x2136); // Signed multiply result high

// ---- PPU: Status (read) ----
pub const RDNMI = reg(0x4210); // V-blank NMI flag and CPU version
pub const TIMEUP = reg(0x4211); // H/V timer IRQ flag
pub const HVBJOY = reg(0x4212); // H/V-blank and joypad status

// ---- NMI / Timer / IRQ ----
pub const NMITIMEN = reg(0x4200); // NMI, timer, and IRQ enable
pub const HTIMEL = reg(0x4207); // H-count timer low
pub const HTIMEH = reg(0x4208); // H-count timer high
pub const VTIMEL = reg(0x4209); // V-count timer low
pub const VTIMEH = reg(0x420a); // V-count timer high

// ---- Joypad ----
pub const JOYWR = reg(0x4201); // Joypad output (latch)
pub const JOY1L = reg(0x4218); // Joypad 1 low byte (auto-read)
pub const JOY1H = reg(0x4219); // Joypad 1 high byte (auto-read)
pub const JOY2L = reg(0x421a); // Joypad 2 low byte (auto-read)
pub const JOY2H = reg(0x421b); // Joypad 2 high byte (auto-read)

// ---- DMA ----
pub const MDMAEN = reg(0x420b); // General-purpose DMA enable (channels 0–7)
pub const HDMAEN = reg(0x420c); // H-blank DMA enable (channels 0–7)

// Per-channel DMA registers (channel n).
pub fn DMAP(comptime n: u3) *volatile u8 {
    return reg(0x4300 + @as(u16, n) * 0x10);
}
pub fn BBAD(comptime n: u3) *volatile u8 {
    return reg(0x4301 + @as(u16, n) * 0x10);
}
pub fn A1TL(comptime n: u3) *volatile u8 {
    return reg(0x4302 + @as(u16, n) * 0x10);
}
pub fn A1TH(comptime n: u3) *volatile u8 {
    return reg(0x4303 + @as(u16, n) * 0x10);
}
pub fn A1B(comptime n: u3) *volatile u8 {
    return reg(0x4304 + @as(u16, n) * 0x10);
}
pub fn DASL(comptime n: u3) *volatile u8 {
    return reg(0x4305 + @as(u16, n) * 0x10);
}
pub fn DASH(comptime n: u3) *volatile u8 {
    return reg(0x4306 + @as(u16, n) * 0x10);
}
pub fn DASB(comptime n: u3) *volatile u8 {
    return reg(0x4307 + @as(u16, n) * 0x10);
}

/// Build a 15-bit BGR colour word (SNES format: 0bbbbbgggggrrrrr).
pub fn color(r: u5, g: u5, b: u5) u16 {
    return @as(u16, r) | (@as(u16, g) << 5) | (@as(u16, b) << 10);
}
