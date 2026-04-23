; Provides the .call_main section required by LLVM-MOS text-sections.ld.
; Without this, main() is never called from the crt0 startup sequence.
.section .call_main,"ax",@progbits
    jsr main
