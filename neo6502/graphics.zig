// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Neo6502 graphics demo: concentric rectangles, an ellipse, and shadowed text.
const api = @import("neo6502");

/// Colours for the eight concentric rectangles (outermost first).
const rect_colors: [8]u8 = .{ 9, 12, 13, 1, 11, 15, 3, 7 };

export fn main() void {
    api.neo_console_clear_screen();

    for (rect_colors, 0..) |color, i| {
        api.neo_graphics_set_color(color);
        api.neo_graphics_draw_rectangle(20 + i, 20 + i, 300 - i, 220 - i);
    }

    api.neo_graphics_set_color(4);
    api.neo_graphics_draw_ellipse(70, 30, 250, 210);

    // Draw "Hello, Neo6502!" three times with decreasing offsets for a drop-shadow effect.
    api.neo_graphics_set_draw_size(3);
    const cx: u16 = (320 - (6 * 8) * 3) / 2;
    const cy: u16 = (240 - (8 * 2) * 3) / 2;
    for (0..3) |i| {
        api.neo_graphics_set_color(@intCast(9 - 2 * i));
        api.neo_graphics_draw_text(cx - i, cy - i, "Hello,");
        api.neo_graphics_draw_text(cx - i, cy - i + 8 * 3, "Neo6502!");
    }

    api.neo_graphics_set_draw_size(1);
    api.neo_graphics_set_color(14);
    api.neo_graphics_draw_text(290 - (6 * 10), 202, "- Zig-MOS");
}
