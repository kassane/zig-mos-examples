// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 Fibonacci — prints fib(0..9) from a ROM lookup table.
pub const panic = @import("mos_panic");
const std = @import("std");

fn fibonacci(comptime n: usize) c_int {
    return if (n <= 1) @intCast(n) else fibonacci(n - 1) + fibonacci(n - 2);
}

const fib_table = blk: {
    var table: [10]c_int = undefined;
    for (0..10) |i| table[i] = fibonacci(i);
    break :blk table;
};

export fn main() void {
    // Split into two single-vararg printf calls: LLVM-MOS misplaces the second
    // c_int vararg (slot 4 instead of slot 2) when the loop is unrolled with
    // two varargs, producing 0 for every fib value.
    var i: c_int = 0;
    const ip: *volatile c_int = &i;
    while (ip.* < 10) : (ip.* += 1) {
        const idx: usize = @intCast(ip.*);
        _ = std.c.printf("fib(%d) = ", ip.*);
        _ = std.c.printf("%d\n", fib_table[idx]);
    }
}
