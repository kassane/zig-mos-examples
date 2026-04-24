// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! PC Engine banked color-cycle demo.
//! Declares ROM bank 1 at virtual offset 6 (0xC000), places cycle_color
//! in that bank section, maps the bank at startup, then loops.

// translate-c cannot handle the volatile pointer cast macros in hardware.h
// (they use C volatile casts that translate-c rejects), so we define the
// VCE registers directly — same addresses as hardware.h.
const IO_VCE_COLOR_INDEX: *volatile u16 = @ptrFromInt(0x0402);
const IO_VCE_COLOR_DATA:  *volatile u16 = @ptrFromInt(0x0404);

var color: u16 = 0;

// Emit the linker symbols that declare bank 1 at ROM offset 6 (8 KB unit).
comptime {
    asm(
        \\.global __rom_bank1
        \\.global __rom_bank1_size
        \\.equ __rom_bank1, (6 << 13)
        \\.equ __rom_bank1_size, (1 << 13)
    );
}

// Map ROM bank 1 to virtual address window 6 (0xC000).
// Mirrors pce_rom_bank1_map() from pce/config.h: lda #bank_num; tam #(1<<6).
fn pceRomBank1Map() void {
    asm volatile(
        \\lda #__rom_bank1_bank
        \\tam #64
    );
}

// Must be noinline and in .rom_bank1 section so the linker places it in bank 1.
noinline fn cycleColor() linksection(".rom_bank1") void {
    IO_VCE_COLOR_INDEX.* = 0x100;
    IO_VCE_COLOR_DATA.* = color;
    color +%= 1;
}

export fn main() void {
    pceRomBank1Map();
    while (true) {
        cycleColor();
    }
}

// Required interrupt handler stubs for PCE vector table.
export fn irq_vdc()   callconv(.c) void {}
export fn irq_timer() callconv(.c) void {}
export fn nmi()       callconv(.c) void {}
export fn irq_ext()   callconv(.c) void {}
export fn irq_vdc_2() callconv(.c) void {}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
