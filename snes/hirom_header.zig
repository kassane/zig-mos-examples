// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//
// SNES HiROM internal ROM header ($FFC0–$FFDF) and interrupt vector table
// ($FFE4–$FFFF). Both sections are placed at fixed addresses by hirom.ld.
//
// Map mode $21 = HiROM. $31 = FastROM HiROM. Use $21 for compatibility.

comptime {
    asm (
        \\.section .snes_header,"a",@progbits
        \\    .ascii "ZIG SNES HIROM       "
        \\    .byte  0x21        /* map mode: HiROM        */
        \\    .byte  0x00        /* ROM type: ROM only      */
        \\    .byte  0x05        /* ROM size: 1 Mbit        */
        \\    .byte  0x00        /* SRAM size: 0            */
        \\    .byte  0x01        /* destination: NTSC       */
        \\    .byte  0x00        /* fixed: $00              */
        \\    .byte  0x00        /* version: 1.0            */
        \\    .word  0xffff      /* checksum complement     */
        \\    .word  0x0000      /* checksum                */
        \\
        \\.extern nmi_handler
        \\.section .vectors,"a",@progbits
        \\    .word  0x0000      /* $FFE4 native COP   */
        \\    .word  0x0000      /* $FFE6 native BRK   */
        \\    .word  0x0000      /* $FFE8 native ABORT */
        \\    .word  nmi_handler /* $FFEA native NMI   */
        \\    .word  0x0000      /* $FFEC (unused)     */
        \\    .word  0x0000      /* $FFEE native IRQ   */
        \\    .word  0x0000      /* $FFF0 emu COP      */
        \\    .word  0x0000      /* $FFF2 (unused)     */
        \\    .word  0x0000      /* $FFF4 emu ABORT    */
        \\    .word  0x0000      /* $FFF6 (unused)     */
        \\    .word  0x0000      /* $FFF8 emu NMI      */
        \\    .word  0x0000      /* $FFFA (unused)     */
        \\    .word  _start      /* $FFFC emu RESET    */
        \\    .word  0x0000      /* $FFFE emu IRQ/BRK  */
    );
}
