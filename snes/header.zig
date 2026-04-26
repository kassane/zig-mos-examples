// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES LoROM internal ROM header ($FFC0–$FFDF) and interrupt vector table
// ($FFE4–$FFFF). Both sections are placed at fixed addresses by lorom.ld.

comptime {
    asm (
        \\.section .snes_header,"a",@progbits
        \\    .ascii "ZIG SNES HELLO       "
        \\    .byte  0x20
        \\    .byte  0x00
        \\    .byte  0x05
        \\    .byte  0x00
        \\    .byte  0x01
        \\    .byte  0x00
        \\    .byte  0x00
        \\    .word  0xffff
        \\    .word  0x0000
        \\
        \\.section .vectors,"a",@progbits
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  0x0000
        \\    .word  _start
        \\    .word  0x0000
    );
}
