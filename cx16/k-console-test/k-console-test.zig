// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Commander X16 kernal console test.
//! Sets screen to 320x240 graphics mode, draws a text console greeting,
//! waits for a keypress, renders a small face bitmap, waits again, then
//! returns to text mode.
pub const panic = @import("mos_panic");

const cx16 = @import("cx16");
const cbm = @import("cbm");

fn waitKey() void {
    while (cbm.cbm_k_getin() == 0) {}
}

fn consolePuts(str: [*:0]const u8, wordwrap: u8) void {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {
        cx16.cx16_k_console_put_char(str[i], wordwrap);
    }
}

const face = [64]u8{
    1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 0, 0, 0, 0, 1, 1,
    1, 0, 1, 0, 0, 1, 0, 1,
    1, 0, 0, 0, 0, 0, 0, 1,
    1, 0, 1, 0, 0, 1, 0, 1,
    1, 0, 0, 1, 1, 0, 0, 1,
    1, 1, 0, 0, 0, 0, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1,
};

export fn main() void {
    _ = cx16.cx16_k_screen_mode_set(128);
    cx16.cx16_k_graph_set_colors(1, 0, 0);
    cx16.cx16_k_console_init(0, 0, 0, 0);
    consolePuts("\x92Hello Commander X16!", 0);

    waitKey();

    cx16.cx16_k_console_put_image(@constCast(&face), 8, 8);

    waitKey();

    _ = cx16.cx16_k_screen_mode_set(0);
    consolePuts("DONE.", 0);
}
