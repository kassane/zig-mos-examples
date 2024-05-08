pub extern fn music_init(music_data: ?*const anyopaque) void;
pub extern fn banked_music_init(bank: u8, music_data: ?*const anyopaque) void;
pub extern fn music_play(song: u8) void;
pub extern fn music_stop() void;
pub extern fn music_pause(pause: u8) void;
pub extern fn sounds_init(sounds_data: ?*const anyopaque) void;
pub extern fn banked_sounds_init(bank: u8, sounds_data: ?*const anyopaque) void;
pub extern fn sfx_play(sound: u8, channel: u8) void;
pub extern fn sample_play(sample: u8) void;
pub extern fn pal_all(data: ?*const anyopaque) void;
pub extern fn pal_bg(data: ?*const anyopaque) void;
pub extern fn pal_spr(data: ?*const anyopaque) void;
pub extern fn pal_col(index: u8, color: u8) void;
pub extern fn pal_clear() void;
pub extern fn pal_bright(bright: u8) void;
pub extern fn pal_spr_bright(bright: u8) void;
pub extern fn pal_bg_bright(bright: u8) void;
pub extern fn ppu_wait_nmi() void;
pub extern fn ppu_wait_frame() void;
pub extern fn ppu_off() void;
pub extern fn ppu_on_all() void;
pub extern fn ppu_on_bg() void;
pub extern fn ppu_on_spr() void;
pub extern fn ppu_mask(mask: u8) void;
pub extern fn ppu_system() u8;
pub extern fn oam_clear() void;
pub extern fn oam_size(size: u8) void;
pub extern fn oam_spr(x: u8, y: u8, chrnum: u8, attr: u8) void;
pub extern fn oam_meta_spr(x: u8, y: u8, data: ?*const anyopaque) void;
pub extern fn oam_hide_rest() void;
pub extern fn oam_set(index: u8) void;
pub extern fn oam_get() u8;
pub extern fn pad_poll(pad: u8) u8;
pub extern fn pad_trigger(pad: u8) u8;
pub extern fn pad_state(pad: u8) u8;
pub extern fn scroll(x: c_uint, y: c_uint) void;
pub extern fn split(x: c_uint) void;
pub extern fn bank_spr(n: u8) void;
pub extern fn bank_bg(n: u8) void;
pub extern fn rand8() u8;
pub extern fn rand16() c_uint;
pub extern fn set_rand(seed: c_uint) void;
pub extern fn set_vram_update(buf: ?*const anyopaque) void;
pub extern fn flush_vram_update(buf: ?*const anyopaque) void;
pub extern fn vram_adr(adr: c_uint) void;
pub extern fn vram_put(n: u8) void;
pub extern fn vram_fill(n: u8, len: c_uint) void;
pub extern fn vram_inc(n: u8) void;
pub extern fn vram_read(dst: ?*anyopaque, size: c_uint) void;
pub extern fn vram_write(src: ?*const anyopaque, size: c_uint) void;
pub extern fn vram_unrle(data: ?*const anyopaque) void;
pub extern fn delay(frames: u8) void;

pub const PAD_A = @as(c_int, 0x80);
pub const PAD_B = @as(c_int, 0x40);
pub const PAD_SELECT = @as(c_int, 0x20);
pub const PAD_START = @as(c_int, 0x10);
pub const PAD_UP = @as(c_int, 0x08);
pub const PAD_DOWN = @as(c_int, 0x04);
pub const PAD_LEFT = @as(c_int, 0x02);
pub const PAD_RIGHT = @as(c_int, 0x01);
pub const OAM_FLIP_V = @as(c_int, 0x80);
pub const OAM_FLIP_H = @as(c_int, 0x40);
pub const OAM_BEHIND = @as(c_int, 0x20);
pub inline fn MAX(x1: anytype, x2: anytype) @TypeOf(if (x1 < x2) x2 else x1) {
    return if (x1 < x2) x2 else x1;
}
pub inline fn MIN(x1: anytype, x2: anytype) @TypeOf(if (x1 < x2) x1 else x2) {
    return if (x1 < x2) x1 else x2;
}
pub const MASK_SPR = @as(c_int, 0x10);
pub const MASK_BG = @as(c_int, 0x08);
pub const MASK_EDGE_SPR = @as(c_int, 0x04);
pub const MASK_EDGE_BG = @as(c_int, 0x02);
pub const NAMETABLE_A = @as(c_int, 0x2000);
pub const NAMETABLE_B = @as(c_int, 0x2400);
pub const NAMETABLE_C = @as(c_int, 0x2800);
pub const NAMETABLE_D = @as(c_int, 0x2c00);
pub const NULL = @as(c_int, 0);
pub const TRUE = @as(c_int, 1);
pub const FALSE = @as(c_int, 0);
pub const NT_UPD_HORZ = @as(c_int, 0x40);
pub const NT_UPD_VERT = @as(c_int, 0x80);
pub const NT_UPD_EOF = @as(c_int, 0xff);
pub inline fn NTADR_A(x: anytype, y: anytype) @TypeOf(NAMETABLE_A | ((y << @as(c_int, 5)) | x)) {
    return NAMETABLE_A | ((y << @as(c_int, 5)) | x);
}
pub inline fn NTADR_B(x: anytype, y: anytype) @TypeOf(NAMETABLE_B | ((y << @as(c_int, 5)) | x)) {
    return NAMETABLE_B | ((y << @as(c_int, 5)) | x);
}
pub inline fn NTADR_C(x: anytype, y: anytype) @TypeOf(NAMETABLE_C | ((y << @as(c_int, 5)) | x)) {
    return NAMETABLE_C | ((y << @as(c_int, 5)) | x);
}
pub inline fn NTADR_D(x: anytype, y: anytype) @TypeOf(NAMETABLE_D | ((y << @as(c_int, 5)) | x)) {
    return NAMETABLE_D | ((y << @as(c_int, 5)) | x);
}
pub inline fn MSB(x: anytype) @TypeOf(x >> @as(c_int, 8)) {
    return x >> @as(c_int, 8);
}
pub inline fn LSB(x: anytype) @TypeOf(x & @as(c_int, 0xff)) {
    return x & @as(c_int, 0xff);
}
