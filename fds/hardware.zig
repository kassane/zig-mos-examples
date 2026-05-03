// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// NES hardware register definitions — mirrors nes.h from llvm-mos-sdk.

fn reg(comptime addr: comptime_int) *volatile u8 {
    return @ptrFromInt(addr);
}

// ---- PPU ($2000–$2007) ----
pub const PPUCTRL = reg(0x2000); // NMI enable, master/slave, sprite height, BG/sprite tiles, addr increment
pub const PPUMASK = reg(0x2001); // colour, show sprites/background, leftmost column enable
pub const PPUSTATUS = reg(0x2002); // vblank flag, sprite-0 hit, sprite overflow (read clears latch)
pub const OAMADDR = reg(0x2003); // OAM address
pub const OAMDATA = reg(0x2004); // OAM data read/write
pub const PPUSCROLL = reg(0x2005); // fine scroll (write twice: X then Y)
pub const PPUADDR = reg(0x2006); // VRAM address (write twice: high then low)
pub const PPUDATA = reg(0x2007); // VRAM data read/write (auto-increments PPUADDR)

// ---- APU: Pulse 1 ($4000–$4003) ----
pub const APU_SQ1_VOL = reg(0x4000); // duty, length counter halt, envelope
pub const APU_SQ1_SWEEP = reg(0x4001); // sweep unit
pub const APU_SQ1_LO = reg(0x4002); // timer low
pub const APU_SQ1_HI = reg(0x4003); // length counter load, timer high

// ---- APU: Pulse 2 ($4004–$4007) ----
pub const APU_SQ2_VOL = reg(0x4004);
pub const APU_SQ2_SWEEP = reg(0x4005);
pub const APU_SQ2_LO = reg(0x4006);
pub const APU_SQ2_HI = reg(0x4007);

// ---- APU: Triangle ($4008–$400B) ----
pub const APU_TRI_LINEAR = reg(0x4008);
pub const APU_TRI_LO = reg(0x400A);
pub const APU_TRI_HI = reg(0x400B);

// ---- APU: Noise ($400C–$400F) ----
pub const APU_NOISE_VOL = reg(0x400C);
pub const APU_NOISE_LO = reg(0x400E);
pub const APU_NOISE_HI = reg(0x400F);

// ---- APU: DMC ($4010–$4013) ----
pub const APU_DMC_FREQ = reg(0x4010);
pub const APU_DMC_RAW = reg(0x4011);
pub const APU_DMC_START = reg(0x4012);
pub const APU_DMC_LEN = reg(0x4013);

// ---- OAM DMA + APU status + Joypad ($4014–$4017) ----
pub const OAMDMA = reg(0x4014); // write $XX: DMA copy page $XX00–$XXFF → OAM
pub const APU_STATUS = reg(0x4015); // channel enable / status
pub const JOY1 = reg(0x4016); // joypad 1 strobe (write) / serial data (read)
pub const JOY2 = reg(0x4017); // joypad 2 read / APU frame counter (write)

// ---- PPUMASK convenience bits ----
pub const MASK_GREYSCALE: u8 = 0x01;
pub const MASK_SHOW_BG_LEFT: u8 = 0x02; // show background in leftmost 8 pixels
pub const MASK_SHOW_SP_LEFT: u8 = 0x04; // show sprites in leftmost 8 pixels
pub const MASK_SHOW_BG: u8 = 0x08;
pub const MASK_SHOW_SP: u8 = 0x10;
pub const MASK_EMPH_R: u8 = 0x20;
pub const MASK_EMPH_G: u8 = 0x40;
pub const MASK_EMPH_B: u8 = 0x80;

// ---- PPUSTATUS bits ----
pub const STATUS_VBLANK: u8 = 0x80;
pub const STATUS_SPRITE0: u8 = 0x40;
pub const STATUS_SP_OVERFLOW: u8 = 0x20;

// ---- PPUCTRL bits ----
pub const CTRL_NMI: u8 = 0x80;
pub const CTRL_MASTER: u8 = 0x40;
pub const CTRL_SP_HEIGHT: u8 = 0x20; // 0=8×8, 1=8×16
pub const CTRL_BG_TABLE: u8 = 0x10; // BG pattern table (0=$0000, 1=$1000)
pub const CTRL_SP_TABLE: u8 = 0x08; // sprite pattern table (0=$0000, 1=$1000)
pub const CTRL_VRAM_INC: u8 = 0x04; // 0=+1 (across), 1=+32 (down)

/// Set PPUADDR to a 16-bit VRAM address (resets the address latch first).
pub inline fn ppuSetAddr(addr: u16) void {
    _ = PPUSTATUS.*;
    PPUADDR.* = @truncate(addr >> 8);
    PPUADDR.* = @truncate(addr & 0xFF);
}

/// Spin until PPUSTATUS reports vblank (bit 7 set).
pub inline fn ppuWaitVblank() void {
    while (PPUSTATUS.* & STATUS_VBLANK == 0) {}
}
