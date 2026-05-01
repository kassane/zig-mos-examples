// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! PC Engine banked color-cycle demo — cycleColor() lives in ROM bank 1.
pub const panic = @import("mos_panic");
const pce = @import("pce");

// IO_VCE_COLOR_INDEX / IO_VCE_COLOR_DATA: hardware.h volatile pointer-cast macros
// are not emitted by translate-c (Aro drops them); keep @ptrFromInt directly.
const IO_VCE_COLOR_INDEX: *volatile u16 = @ptrFromInt(0x0402);
const IO_VCE_COLOR_DATA: *volatile u16 = @ptrFromInt(0x0404);

// Declare physical bank 1 at ROM offset 6 (0xC000).  Mirrors PCE_ROM_BANK_AT(1, 6).
comptime {
    asm (
        \\.global __rom_bank1
        \\.global __rom_bank1_size
        \\.equ __rom_bank1, (6 << 13)
        \\.equ __rom_bank1_size, (1 << 13)
    );
}

// Map ROM bank 1 to virtual address window 6 (0xC000).
// Mirrors pce_rom_bank1_map(): lda #bank_num; tam #(1<<6).
fn pceRomBank1Map() void {
    asm volatile (
        \\lda #__rom_bank1_bank
        \\tam #64
    );
}

var color: u16 = 0;

// Placed in ROM bank 1 so it runs from the banked window.
noinline fn cycleColor() linksection(".rom_bank1") void {
    IO_VCE_COLOR_INDEX.* = 0x100;
    IO_VCE_COLOR_DATA.* = color;
    color +%= 1;
}

export fn main() void {
    pce.pce_vdc_set_resolution(256, 240, 0);
    pceRomBank1Map();
    while (true) {
        cycleColor();
    }
}
