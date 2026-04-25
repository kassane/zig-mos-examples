// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES LoROM startup: executes at reset in W65C816S emulation mode.
// Switches to native 65816 mode, sets the direct page and data bank to bank 0,
// and initialises the hardware stack before the common .init.* chain runs.
//
// This file is added directly to each exe (not via library) because it defines
// no externally-referenced symbols — the linker would skip it from an archive.

.section .init.000,"ax",@progbits
    sei                 // disable IRQs during init
    cld                 // clear decimal mode

    // Set hardware stack to $01FF while still in emulation mode.
    // In emulation mode txs forces the high byte to $01, so X=$FF → S=$01FF.
    ldx #0xff
    txs

    // Switch from 6502 emulation mode to W65C816S native mode.
    // S keeps its $01FF value across the XCE transition.
    clc                 // carry = 0
    xce                 // exchange carry ↔ emulation bit: E=0 → native mode
                        // After XCE: M=1 (8-bit A), X=1 (8-bit X/Y)

    // Set the Direct Page register to $0000.
    // PEA always pushes a 16-bit immediate; PLD always pops 16 bits into D.
    pea 0x0000
    pld                 // D = $0000: DP addressing maps to WRAM $0000–$00FF

    // Set the Data Bank Register to $00 (same bank as program code).
    phk                 // push Program Bank Register ($00)
    plb                 // pop to Data Bank Register: DBR = $00
