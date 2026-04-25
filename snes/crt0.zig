// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES LoROM startup: W65C816S emulation→native mode switch.
// Runs in .init.000 so it executes before the common .init.* chain.

comptime {
    asm (
        \\.section .init.000,"ax",@progbits
        \\    sei
        \\    cld
        \\    ldx #0xff
        \\    txs
        \\    clc
        \\    xce
        \\    pea 0x0000
        \\    pld
        \\    phk
        \\    plb
    );
}
