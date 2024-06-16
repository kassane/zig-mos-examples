//! based on original graphics.c (lvm-mos-sdk/examples/neo6502/graphics.c)

const api = @import("neo_api.zig");

export fn main() void {
    const rectangle_colors = [_]u8{ 9, 12, 13, 1, 11, 15, 3, 7 };

    api.neo_console_clear_screen();
    for (0..rectangle_colors.len) |i| {
        api.neo_graphics_set_color(rectangle_colors[i]);
        api.neo_graphics_draw_rectangle(20 + i, 20 + i, 300 - i, 220 - i);
    }

    api.neo_graphics_set_color(4);
    api.neo_graphics_draw_ellipse(70, 30, 250, 210);

    api.neo_graphics_set_draw_size(3);
    for (0..3) |i| {
        api.neo_graphics_set_color(@intCast(9 - 2 * i));
        const center_x: u16 = (320 - (6 * 8) * 3) / 2;
        const center_y: u16 = (240 - (8 * 2) * 3) / 2;
        api.neo_graphics_draw_text(center_x - i, center_y - i, "Hello,");
        api.neo_graphics_draw_text(center_x - i, center_y - i + 8 * 3, "Neo6502!");
    }

    api.neo_graphics_set_draw_size(1);
    api.neo_graphics_set_color(14);
    api.neo_graphics_draw_text(290 - (6 * 10), 202, "- Zig-MOS");
}
