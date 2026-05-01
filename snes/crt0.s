; Copyright (c) 2024 Matheus C. França
; SPDX-License-Identifier: Apache-2.0
;
; SNES LoROM startup: W65C816S emulation→native mode switch.
; Runs in .init.000 so it executes before the common .init.* chain.
; Compiled as a raw assembly file so it bypasses LTO IR and is
; assembled directly by the MC layer which supports all 65816 instructions.

    .section .init.000,"ax",@progbits
    sei
    cld
    ldx #0xff
    txs
    clc
    xce
    pea 0x0000
    pld
    lda #0x00           ; explicit DB=0: safe for both LoROM (bank $00) and HiROM (bank $C0+)
    pha
    plb

    .extern vblank_flag
    .section .text.nmi_handler,"ax",@progbits
    .global nmi_handler
nmi_handler:
    rep #0x30           ; 16-bit A, X, Y at runtime
    pha                 ; save A (16-bit)
    phx                 ; save X (16-bit)
    phy                 ; save Y (16-bit)
    sep #0x20           ; M=1: assembler and runtime now agree — all lda # below are 8-bit
    phb                 ; save data bank (8-bit, always)
    phd                 ; save direct page (16-bit, always)
    lda #0x00
    pha
    plb                 ; DB = 0
    lda #0x01
    sta vblank_flag     ; signal VBlank to wait_vblank()
    pld                 ; restore direct page
    plb                 ; restore data bank
    rep #0x30           ; 16-bit for restoring A/X/Y
    ply
    plx
    pla
    rti
