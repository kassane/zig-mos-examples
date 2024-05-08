pub extern fn set_vram_buffer() void;
pub extern fn one_vram_buffer(data: u8, ppu_address: c_int) void;
pub extern fn multi_vram_buffer_horz(data: ?*const anyopaque, len: u8, ppu_address: c_int) void;
pub extern fn multi_vram_buffer_vert(data: ?*const anyopaque, len: u8, ppu_address: c_int) void;
pub extern fn get_pad_new(pad: u8) u8;
pub extern fn get_frame_count() u8;
pub extern fn set_music_speed(tempo: u8) void;
pub extern fn check_collision(object1: ?*anyopaque, object2: ?*anyopaque) u8;
pub extern fn pal_fade_to(from: u8, to: u8) void;
pub extern fn set_scroll_x(x: c_uint) void;
pub extern fn set_scroll_y(y: c_uint) void;
pub extern fn add_scroll_y(add: u8, scroll: c_uint) c_int;
pub extern fn sub_scroll_y(sub: u8, scroll: c_uint) c_int;
pub extern fn get_ppu_addr(nt: u8, x: u8, y: u8) c_int;
pub extern fn get_at_addr(nt: u8, x: u8, y: u8) c_int;
pub extern fn set_data_pointer(data: ?*const anyopaque) void;
pub extern fn set_mt_pointer(metatiles: ?*const anyopaque) void;
pub extern fn buffer_1_mt(ppu_address: c_int, metatile: u8) void;
pub extern fn buffer_4_mt(ppu_address: c_int, index: u8) void;
pub extern fn flush_vram_update2() void;
pub extern fn color_emphasis(color: u8) void;
pub extern fn xy_split(x: c_uint, y: c_uint) void;
pub extern fn gray_line() void;
pub extern fn seed_rng() void;

pub const COL_EMP_BLUE = @as(c_int, 0x80);
pub const COL_EMP_GREEN = @as(c_int, 0x40);
pub const COL_EMP_RED = @as(c_int, 0x20);
pub const COL_EMP_NORMAL = @as(c_int, 0x00);
pub const COL_EMP_DARK = @as(c_int, 0xe0);
pub inline fn high_byte(a: anytype) @TypeOf((@import("std").zig.c_translation.cast([*c]u8, &a) + @as(c_int, 1)).*) {
    return (@import("std").zig.c_translation.cast([*c]u8, &a) + @as(c_int, 1)).*;
}
pub inline fn low_byte(a: anytype) @TypeOf(@import("std").zig.c_translation.cast([*c]u8, &a).*) {
    return @import("std").zig.c_translation.cast([*c]u8, &a).*;
}
