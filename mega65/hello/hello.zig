const std = @import("std");
const mega65 = @import("mega65");

extern fn lpoke(address: u32, value: u8) void;
extern fn lpeek(address: u32) u8;

const vic: *volatile mega65.__vic4 = @ptrFromInt(0xd000);

export fn main() void {
    _ = std.c.printf("Hello World!\n");
    vic.bordercol = 5; // 0xD020
    lpoke(0x40000, 0);
    vic.screencol = lpeek(0x40000); // 0xD021
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
