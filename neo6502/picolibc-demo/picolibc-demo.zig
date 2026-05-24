// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Neo6502 picolibc demo: exercises string.h functions from picolibc.
pub const panic = @import("mos_panic");

const api = @import("neo6502");

const pc = @import("picolibc");

export fn main() void {
    api.neo_console_clear_screen();

    api.neo_graphics_set_color(7);
    api.neo_graphics_set_draw_size(2);
    api.neo_graphics_draw_text(10, 40, "picolibc demo");

    const s = "picolibc";
    const n = pc.strlen(s);
    // n == 8; display as static label
    api.neo_graphics_set_draw_size(1);
    api.neo_graphics_set_color(14);
    if (n == 8) {
        api.neo_graphics_draw_text(10, 80, "strlen(picolibc)=8 OK");
    } else {
        api.neo_graphics_draw_text(10, 80, "strlen FAIL");
    }

    const r = pc.strcmp("abc", "abc");
    if (r == 0) {
        api.neo_graphics_draw_text(10, 100, "strcmp(abc,abc)=0 OK");
    } else {
        api.neo_graphics_draw_text(10, 100, "strcmp FAIL");
    }
}
