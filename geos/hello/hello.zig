// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
pub const panic = @import("mos_panic");

const geos = @import("geos");

// Clear screen: pattern 2 (white), rectangle from (0,0) to (319,199)
// WORD(x) expands to lo,hi bytes: WORD(0)=0,0  WORD(319)=0x3F,0x01
const clear_screen = [_]u8{
    geos.NEWPATTERN,  2,
    geos.MOVEPENTO,   0,
    0,                0,
    geos.RECTANGLETO, 0x3F,
    0x01,             199,
    0,
};

const hello_str = "Hello, Zig!" ++ [_]u8{0};

// GEOS zero-page argument registers (geos.ld)
fn r0() *volatile u16 {
    return @ptrFromInt(0x0002);
} // __r0 = str ptr / GraphicsString arg
fn r1H() *volatile u8 {
    return @ptrFromInt(0x0005);
} // __r1H = y
fn r11() *volatile u16 {
    return @ptrFromInt(0x0018);
} // __r11 = x

// Raw GEOS kernel jump table entries (geos.ld)
extern fn __GraphicsString() void; // 0xc136
extern fn __PutString() void; // 0xc148
extern fn __UseSystemFont() void; // 0xc14b
extern fn __MainLoop() void; // 0xc1c3

fn graphicsString(graph_string: [*]const u8) void {
    r0().* = @intFromPtr(graph_string);
    __GraphicsString();
}

fn putString(x: u16, y: u8, str: [*:0]const u8) void {
    r11().* = x;
    r1H().* = y;
    r0().* = @intFromPtr(str);
    __PutString();
}

export fn main() void {
    geos.dispBufferOn = geos.ST_WR_FORE | geos.ST_WR_BACK;
    graphicsString(&clear_screen);
    __UseSystemFont();
    putString(80, 90, hello_str[0.. :0].ptr);
    __MainLoop();
}
