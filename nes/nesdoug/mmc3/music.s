; Music and sound-effect data for the MMC3 nesdoug demo.
; Placed in PRG ROM bank 12 so they are reachable via banked_music_init /
; banked_sounds_init(12, ...).

    .section .prg_rom_12.music_data,"a",@progbits
    .globl music_data
music_data:
    .include "TestMusic3.s"

    .section .prg_rom_12.sounds_data,"a",@progbits
    .globl sounds_data
sounds_data:
    .include "SoundFx.s"
