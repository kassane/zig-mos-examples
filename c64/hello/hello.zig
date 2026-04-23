//! C64 "Hello World" via the KERNAL-compatible stdio layer.
const std = @import("std");

export fn main() void {
    _ = std.c.printf("Hello World!\n");
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = std.c.printf("PANIC: %s\n", msg.ptr);
    while (true) {}
}
