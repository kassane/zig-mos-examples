/* Copyright (c) 2024 Matheus C. França                          */
/* SPDX-License-Identifier: Apache-2.0                           */
/*                                                               */
/* SNES FastROM LoROM — single 32 KiB PRG bank ($80:8000–$80:FFFF). */
/*                                                               */
/* ROM is placed in bank $80 so instruction fetches run at       */
/* 3.58 MHz (FastROM speed) after $420D is set to 1 in crt0.    */
/* WRAM and I/O remain at the same addresses as LoROM.           */
/*                                                               */
/* Memory map (bank $80):                                        */
/*   $0000–$00FF  Direct page / ZP (WRAM mirror, first 256 B)   */
/*   $0100–$01FF  Hardware stack (WRAM mirror)                   */
/*   $0200–$1FFF  WRAM (data / BSS / soft stack)                 */
/*   $2000–$5FFF  Hardware I/O registers (not addressable here)  */
/*   $8000–$FFFF  ROM bank $80 (32 KiB)                          */

/* Imaginary (zero-page / direct-page) registers __rc0–__rc31. */
__rc0 = 0x0000;
INCLUDE imag-regs.ld
ASSERT(__rc31 == 0x001f, "Inconsistent zero page map.")

/* ROM access speed for MEMSEL ($420D): 0=SlowROM, 1=FastROM.   */
/* crt0.s reads this symbol as an immediate and writes $420D.    */
__snes_memsel = 1;

MEMORY {
    /* Direct page: bytes after imaginary regs, up to end of page */
    zp  (rw) : ORIGIN = __rc31 + 1, LENGTH = 0x100 - (__rc31 + 1)
    /* WRAM: $0200–$1FFF (stack page $0100–$01FF reserved for hardware stack) */
    ram (rw) : ORIGIN = 0x0200, LENGTH = 0x1e00
    /* ROM bank $80: FastROM window — same physical data as bank $00 mirror */
    rom (rx) : ORIGIN = 0x808000, LENGTH = 0x8000
}

REGION_ALIAS("c_readonly",  rom)
REGION_ALIAS("c_writeable", ram)

/* Soft stack grows down from the top of WRAM. */
__stack = 0x2000;

SECTIONS {
    INCLUDE c.ld

    /* SNES internal ROM header: 32 bytes at $80:FFC0–$80:FFDF. */
    .snes_header 0x80ffc0 : { KEEP(*(.snes_header)) } >rom

    /* Interrupt vector table: 28 bytes at $80:FFE4–$80:FFFF. */
    .vectors 0x80ffe4 : { KEEP(*(.vectors)) } >rom
}

OUTPUT_FORMAT {
    FULL(rom)
}
