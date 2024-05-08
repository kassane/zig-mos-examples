export fn main() void {
    _ = std.c.printf("Hello World!\n");
}
const std = @import("std");

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);
    _ = std.c.printf("PANIC: caused by %s\n", msg.ptr);
}
