; Music and sound-effect data for the full-game NROM demo.
; Placed in .rodata so the linker puts it in PRG ROM.
; addIncludePath(b.path("nes/nesdoug/mmc3")) resolves .include directives.

    .section .rodata.music_data,"a",@progbits
    .globl music_data
music_data:
    .include "TestMusic3.s"

    .section .rodata.sounds_data,"a",@progbits
    .globl sounds_data
sounds_data:
    .include "SoundFx.s"
