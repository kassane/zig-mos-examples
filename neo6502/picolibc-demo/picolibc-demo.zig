// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Neo6502 picolibc demo: exercises substring search from picolibc.
pub const panic = @import("mos_panic");

const api = @import("neo6502");

const pc = @import("picolibc");

export fn main() void {
    api.neo_console_clear_screen();

    api.neo_graphics_set_color(7);
    api.neo_graphics_set_draw_size(2);
    api.neo_graphics_draw_text(10, 40, "picolibc demo");

    api.neo_graphics_set_draw_size(1);
    api.neo_graphics_set_color(14);

    // strstr: "libc" is a substring of "picolibc demo".
    const found = pc.strstr("picolibc demo", "libc");
    if (found != null) {
        api.neo_graphics_draw_text(10, 80, "strstr(libc) found OK");
    } else {
        api.neo_graphics_draw_text(10, 80, "strstr FAIL");
    }

    // strrchr: last '/' in a path-like string.
    const last = pc.strrchr("a/b/c", '/');
    if (last != null and last[0] == '/') {
        api.neo_graphics_draw_text(10, 100, "strrchr(last /) OK");
    } else {
        api.neo_graphics_draw_text(10, 100, "strrchr FAIL");
    }
}
