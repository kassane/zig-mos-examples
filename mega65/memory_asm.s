; 45GS02 28-bit flat-memory helpers: lpoke (write) and lpeek (read).
;
; The 45GS02 Z-register instructions (ldz, sta/lda [zp32],z) cannot be
; emitted as mnemonics by the zig-mos assembler, so they are encoded
; directly as .byte sequences.
;
;   ldz  #0           => 0xa3 0x00
;   sta  [rc5_ptr],z  => 0x42 0x42 0x92 <zp>   (NEG NEG + STA (zp),Z, 32-bit indirect)
;   lda  [rc4_ptr],z  => 0x42 0x42 0xb2 <zp>   (NEG NEG + LDA (zp),Z, 32-bit indirect)
;
; LLVM-MOS ABI for mos-mega65 (commodore ZP layout, __basic_zp_start = 0x02):
;   __rc0=0x02  __rc1=0x03  __rc2=0x04  __rc3=0x05
;   __rc4=0x06  __rc5=0x07  __rc6=0x08  __rc7=0x09  __rc8=0x0a

.global lpoke
.section .text.lpoke,"ax",@progbits
lpoke:
        ; 32-bit address arrives as: A=bits[7:0], X=bits[15:8], __rc2=bits[23:16], __rc3=bits[27:24]
        ; 8-bit value to write is in __rc4
        sta __rc5
        stx __rc6
        lda __rc2
        sta __rc7
        lda __rc3
        sta __rc8
        lda __rc4
        .byte 0xa3, 0x00              ; ldz #0
        .byte 0x42, 0x42, 0x92, 0x07  ; sta [__rc5],z  (32-bit ZP indirect + Z)
        rts

.global lpeek
.section .text.lpeek,"ax",@progbits
lpeek:
        ; 32-bit address arrives as: A=bits[7:0], X=bits[15:8], __rc2=bits[23:16], __rc3=bits[27:24]
        ; returns 8-bit value in A
        sta __rc4
        stx __rc5
        lda __rc2
        sta __rc6
        lda __rc3
        sta __rc7
        .byte 0xa3, 0x00              ; ldz #0
        .byte 0x42, 0x42, 0xb2, 0x06  ; lda [__rc4],z  (32-bit ZP indirect + Z)
        rts
