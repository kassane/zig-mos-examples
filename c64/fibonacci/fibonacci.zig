//! C64 Fibonacci — computes and prints fib(0..9) using comptime recursion.
const std = @import("std");

/// Recursive Fibonacci evaluated at comptime when called with a comptime argument.
fn fibonacci(comptime T: type, n: T) T {
    return if (n < 2) n else fibonacci(T, n - 1) + fibonacci(T, n - 2);
}

export fn main() void {
    comptime var i: u8 = 0;
    inline while (i < 10) : (i += 1) {
        _ = std.c.printf("fib(%d) = %d\n", @as(c_int, i), @as(c_int, fibonacci(u8, i)));
    }
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
