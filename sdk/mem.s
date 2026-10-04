; Copyright (c) 2024 Matheus C. França
; SPDX-License-Identifier: Apache-2.0
;
; mem.s — correct __memset and abort for MOS 6502/65816 platforms.
;
; zig cc (clang 21) fails to generate correct pointer-write loop code for the
; MOS 6502 target, producing a recursive stub instead of actual memory writes.
; This strong definition overrides the __attribute__((weak)) __memset in mem.c.
;
; Calling convention (MOS 6502) — matches what clang generates for
; __memset(char *ptr, char value, size_t num). rc0/rc1 hold the software stack
; pointer, so arguments start at rc2. The rc base is per-platform (0x00 on NES,
; 0x02 on Commodore, ...), hence the __rcN symbols, never fixed ZP addresses:
;   A           = fill byte (value)
;   __rc2/__rc3 = destination pointer lo/hi
;   X           = count_lo  (low byte of size_t count)
;   __rc4       = count_hi  (high byte of size_t count)
;
; abort — bare-metal halt loop (strong symbol).
; std.process.abort() lowers to C abort() for unknown OS tags (.nes/.snes).
; Debug builds pull it in transitively through std.debug.defaultPanic.

    .zeropage __rc2, __rc3, __rc4

    .global __memset
    .section .text.__memset,"ax",@progbits

__memset:
    ; Handle count_hi full pages (256 bytes each)
    ldy     __rc4
    beq     .Lpartial

.Lpages:
    ldy     #0
.Lpage_loop:
    sta     (__rc2),y       ; write fill byte at (rc2/rc3 + Y)
    iny
    bne     .Lpage_loop     ; loop Y: 0..255 (256 writes per page)
    inc     __rc3           ; advance destination high byte to next page
    dec     __rc4
    bne     .Lpages         ; repeat for every full page

.Lpartial:
    ; Handle count_lo remaining bytes (0..X-1)
    cpx     #0
    beq     .Ldone
    ldy     #0
.Lpartial_loop:
    sta     (__rc2),y
    iny
    dex
    bne     .Lpartial_loop

.Ldone:
    rts

    .global abort
    .section .text.abort,"ax",@progbits

abort:
    jmp     abort
