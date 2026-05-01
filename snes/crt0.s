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
    lda #__snes_memsel  ; 0=SlowROM (lorom.ld/hirom.ld), 1=FastROM (fastrom.ld)
    sta 0x420d          ; MEMSEL: set ROM access speed before any ROM-intensive code runs

    .extern __snes_memsel
    .extern vblank_flag
    .extern pad_keys
    .extern pad_keysold
    .extern pad_keysdown
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
    ; --- joypad auto-read (uses only abs operands — no lda #imm after rep) ---
    rep #0x30           ; 16-bit A for 16-bit joypad reads
    lda pad_keys        ; save pad1 previous state
    sta pad_keysold
    lda 0x4218          ; read JOY1L/H (16-bit auto-read result)
    sta pad_keys
    eor pad_keysold     ; new XOR previous
    and pad_keys        ; (new XOR previous) AND new = 0→1 transitions
    sta pad_keysdown
    lda pad_keys+2      ; pad2: save previous state
    sta pad_keysold+2
    lda 0x421a          ; read JOY2L/H
    sta pad_keys+2
    eor pad_keysold+2
    and pad_keys+2
    sta pad_keysdown+2
    ; --- restore (M=0/X=0 from rep above — pld/plb are M-independent) ---
    pld                 ; restore direct page (always 16-bit)
    plb                 ; restore data bank (always 8-bit)
    ply
    plx
    pla
    rti
