// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES LoROM internal ROM header ($FFC0–$FFDF) and interrupt vector table
// ($FFE4–$FFFF).  Both sections are placed at fixed addresses by lorom.ld.

// ---------------------------------------------------------------------------
// Internal ROM header — 32 bytes at $FFC0
// ---------------------------------------------------------------------------
.section .snes_header,"a",@progbits
    .ascii "ZIG SNES HELLO       "  // $FFC0–$FFD4: 21-byte title (ASCII, space-padded)
    .byte  0x20                      // $FFD5: map mode — LoROM, SlowROM ($20)
    .byte  0x00                      // $FFD6: cartridge type — ROM only
    .byte  0x05                      // $FFD7: ROM size — 32 KiB (2^5)
    .byte  0x00                      // $FFD8: SRAM size — none
    .byte  0x01                      // $FFD9: country — USA / NTSC
    .byte  0x00                      // $FFDA: developer ID
    .byte  0x00                      // $FFDB: ROM version
    .word  0xffff                    // $FFDC–$FFDD: checksum complement (placeholder)
    .word  0x0000                    // $FFDE–$FFDF: checksum (placeholder)

// ---------------------------------------------------------------------------
// Interrupt vector table — 28 bytes at $FFE4–$FFFF
// Native mode vectors ($FFE4–$FFEF), then emulation mode ($FFF4–$FFFF).
// The 4-byte gap $FFE0–$FFE3 between header and vectors is filled by the linker.
// ---------------------------------------------------------------------------
.section .vectors,"a",@progbits
    // Native mode ($FFE4)
    .word  0x0000   // $FFE4: COP
    .word  0x0000   // $FFE6: BRK
    .word  0x0000   // $FFE8: ABORT
    .word  0x0000   // $FFEA: NMI
    .word  0x0000   // $FFEC: reserved
    .word  0x0000   // $FFEE: IRQ

    // Reserved gap $FFF0–$FFF3
    .word  0x0000   // $FFF0
    .word  0x0000   // $FFF2

    // Emulation mode ($FFF4)
    .word  0x0000   // $FFF4: COP
    .word  0x0000   // $FFF6: reserved
    .word  0x0000   // $FFF8: ABORT
    .word  0x0000   // $FFFA: NMI
    .word  _start   // $FFFC: RESET — entry point
    .word  0x0000   // $FFFE: IRQ/BRK
