// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! PC Engine color-cycle demo — VCE entry 0x100 (backdrop) cycles through 9-bit colors.
pub const panic = @import("mos_panic");
const pce = @import("pce");

// IO_VCE_COLOR_INDEX / IO_VCE_COLOR_DATA: hardware.h volatile pointer-cast macros
// are not emitted by translate-c (Aro drops them); keep @ptrFromInt directly.
const IO_VCE_COLOR_INDEX: *volatile u16 = @ptrFromInt(0x0402);
const IO_VCE_COLOR_DATA: *volatile u16 = @ptrFromInt(0x0404);
const IRQ_VDC: u8 = 0x02;

// ticks and irq_vdc are defined together in module-level asm so that the asm
// reference "inc ticks" is resolved by the assembler/linker rather than the
// LTO optimizer (which treats inline-asm symbol names as opaque text and
// cannot match them to LLVM IR globals).
extern var ticks: u16;
comptime {
    asm (
        \\.section .bss
        \\.global ticks
        \\ticks:
        \\  .space 2
        \\
        \\.section .text
        \\.global irq_vdc
        \\irq_vdc:
        \\  pha
        \\  txa
        \\  pha
        \\  tya
        \\  pha
        \\  lda mos16($0000)
        \\  and #0x20
        \\  beq .Lskip_ticks
        \\  inc ticks
        \\  bne .Lskip_ticks
        \\  inc ticks+1
        \\.Lskip_ticks:
        \\  pla
        \\  tay
        \\  pla
        \\  tax
        \\  pla
        \\  rti
    );
}

export fn main() void {
    pce.pce_vdc_set_resolution(256, 240, 0);
    pce.pce_vdc_irq_vblank_enable();
    pce.pce_irq_enable(IRQ_VDC);
    asm volatile ("cli"); // enable CPU IRQs (pce_cpu_irq_enable inline asm not translated)
    const tp: *volatile u16 = &ticks;
    while (true) {
        IO_VCE_COLOR_INDEX.* = 0x100;
        IO_VCE_COLOR_DATA.* = tp.* >> 3;
    }
}
