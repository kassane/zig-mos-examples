/* Copyright (c) 2024 Matheus C. França                          */
/* SPDX-License-Identifier: Apache-2.0                           */
/*                                                               */
/* SNES HiROM — single 32 KiB bank ($00:8000–$00:FFFF).         */
/*                                                               */
/* Small HiROM ROMs keep code in the $8000-$FFFF window which    */
/* is accessible in banks $00-$3F even in HiROM mode. The map   */
/* mode byte in the ROM header ($FFD5 = $21) distinguishes this  */
/* from LoROM. For multi-bank ROMs the full 64 KiB per bank is   */
/* used, but a single-bank example fits here identically.        */
/*                                                               */
/* Memory map (bank $00):                                        */
/*   $0000–$00FF  Direct page / ZP (WRAM mirror, first 256 B)   */
/*   $0100–$01FF  Hardware stack (WRAM mirror)                   */
/*   $0200–$1FFF  WRAM (data / BSS / soft stack)                 */
/*   $2000–$5FFF  Hardware I/O registers (not addressable here)  */
/*   $8000–$FFFF  ROM bank 0 (32 KiB)                            */

/* Imaginary (zero-page / direct-page) registers __rc0–__rc31. */
__rc0 = 0x0000;
INCLUDE imag-regs.ld
ASSERT(__rc31 == 0x001f, "Inconsistent zero page map.")

MEMORY {
    /* Direct page: bytes after imaginary regs, up to end of page */
    zp  (rw) : ORIGIN = __rc31 + 1, LENGTH = 0x100 - (__rc31 + 1)
    /* WRAM: $0200–$1FFF (stack page $0100–$01FF reserved for hardware stack) */
    ram (rw) : ORIGIN = 0x0200, LENGTH = 0x1e00
    /* ROM bank 0: full 32 KiB window */
    rom (rx) : ORIGIN = 0x8000, LENGTH = 0x8000
}

REGION_ALIAS("c_readonly",  rom)
REGION_ALIAS("c_writeable", ram)

/* Soft stack grows down from the top of WRAM. */
__stack = 0x2000;

SECTIONS {
    INCLUDE c.ld

    /* SNES internal ROM header: 32 bytes at $FFC0–$FFDF. */
    .snes_header 0xffc0 : { KEEP(*(.snes_header)) } >rom

    /* Interrupt vector table: 28 bytes at $FFE4–$FFFF.
     * The 4-byte gap $FFE0–$FFE3 between header and vectors is zero-filled. */
    .vectors 0xffe4 : { KEEP(*(.vectors)) } >rom
}

OUTPUT_FORMAT {
    FULL(rom)
}
