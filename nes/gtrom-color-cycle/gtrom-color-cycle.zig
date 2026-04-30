// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES GTROM colour-cycle with LED control: cycles the universal BG colour
//! through all 64 NES palette entries.  Press Start to toggle the green LED;
//! press Select to toggle the red LED on the GTROM (mapper 111) PCB.
pub const panic = @import("mos_panic");
const neslib = @import("neslib");
const nesdoug = @import("nesdoug");
const mapper = @import("mapper");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    _ = mapper.set_prg_bank(0);
    mapper.set_chr_bank(0);
    mapper.set_nt_bank(0);
    _ = mapper.set_mapper_green_led(true);
    _ = mapper.set_mapper_red_led(false);
    neslib.pal_bg(&(.{0x0f} ** 16));
    neslib.ppu_on_bg();

    var color: u8 = 0;
    var green_on: bool = true;
    var red_on: bool = false;

    while (true) {
        for (0..30) |_| neslib.ppu_wait_nmi(); // ~0.5 s at 60 Hz NTSC
        color = (color +% 1) & 0x3f;
        neslib.pal_col(0, color);

        _ = neslib.pad_poll(0);
        const pad_new = nesdoug.get_pad_new(0);
        if (pad_new & 0x10 != 0) { // PAD_START — toggle green LED
            green_on = !green_on;
            _ = mapper.set_mapper_green_led(green_on);
        }
        if (pad_new & 0x20 != 0) { // PAD_SELECT — toggle red LED
            red_on = !red_on;
            _ = mapper.set_mapper_red_led(red_on);
        }
    }
}
