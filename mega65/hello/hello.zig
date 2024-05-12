const std = @import("std");

// const c = @cImport({
// @cInclude("mega65/memory.h");
//pub const POKE = @compileError("unable to translate C expr: unexpected token 'volatile'");
// });

extern fn lpoke(address: u32, value: u8) void;
extern fn lpeek(address: u32) u8;

export fn main() void {
    _ = std.c.printf("Hello World!\n");
    _ = POKE(0xD020, 5);
    lpoke(0x40000, 0);
    const col = lpeek(0x40000);
    _ = POKE(0xD021, col);
}

pub inline fn POKE(X: anytype, Y: anytype) @TypeOf(std.zig.c_translation.cast(*u8, X).* + Y) {
    return std.zig.c_translation.cast(*u8, X).* + Y;
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
