const std = @import("std");

fn fibonacci(comptime T: type, index: T) T {
    if (index < 2) return index;
    return fibonacci(T, index - 1) + fibonacci(T, index - 2);
}

export fn main() void {
    const value: f32 = 15.30;
    _ = std.c.printf("Value of fibonacci(%.2f) is %.2f\n", value, fibonacci(f32, value));
}

// Fix llvm.debugtrap (no @breakpoint) - override panic handler
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    _ = std.c.printf("PANIC: caused by %s\n", msg.ptr);

    while (true) {}
}
