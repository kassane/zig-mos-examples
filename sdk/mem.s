; Copyright (c) 2024 Matheus C. França
; SPDX-License-Identifier: Apache-2.0
;
; mem.s — correct __memset for NES/MOS 6502
;
; zig cc (clang 21) fails to generate correct pointer-write loop code for the
; MOS 6502 target, producing a recursive stub instead of actual memory writes.
; This strong definition overrides the __attribute__((weak)) __memset in mem.c.
;
; Calling convention (MOS 6502):
;   A        = fill byte (value)
;   $2/$3    = destination pointer lo/hi (rc2/rc3)
;   X        = count_hi  (high byte of size_t count)
;   $4       = count_lo  (low byte  of size_t count, rc4)

    .global __memset
    .section .text,"ax",@progbits

__memset:
    ; Handle count_hi full pages (256 bytes each)
    cpx     #0
    beq     .Lpartial

.Lpages:
    ldy     #0
.Lpage_loop:
    sta     ($2),y          ; write fill byte at (rc2/rc3 + Y)
    iny
    bne     .Lpage_loop     ; loop Y: 0..255 (256 writes per page)
    inc     $3              ; advance destination high byte to next page
    dex
    bne     .Lpages         ; repeat for every full page

.Lpartial:
    ; Handle count_lo remaining bytes (0..count_lo-1)
    ldy     $4              ; Y = count_lo
    beq     .Ldone
    ldy     #0
.Lpartial_loop:
    sta     ($2),y
    iny
    cpy     $4              ; stop when Y == count_lo
    bne     .Lpartial_loop

.Ldone:
    rts
