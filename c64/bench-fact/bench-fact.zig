// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 Factorial benchmark: accumulates factorials 0–15 over 1000 iterations.
//! Zig feature: factorial table computed entirely at compile time (comptime block)
//! and stored as ROM constants — zero runtime cost for the factorial computation.
pub const panic = @import("mos_panic");
const std = @import("std");

const SIZE: usize = 16;
const N_ITER: c_int = 1000;
const EXPECTED: i32 = 188806544;

// Comptime factorial table: all 16 values computed by the Zig compiler, placed
// in ROM (.rodata). Replaces the runtime recursive fact() call from the original
// C benchmark entirely — wrapping *% matches i32 overflow of C `long` on MOS.
const fact_table: [SIZE]i32 = blk: {
    var t: [SIZE]i32 = undefined;
    t[0] = 1;
    for (1..SIZE) |i| t[i] = t[i - 1] *% @as(i32, @intCast(i));
    break :blk t;
};

// Comptime assertions: spot-check known factorial values.
// 12! = 479001600 is the last value that fits in i32 without wrapping.
comptime {
    std.debug.assert(fact_table[0] == 1);
    std.debug.assert(fact_table[5] == 120);
    std.debug.assert(fact_table[10] == 3628800);
    std.debug.assert(fact_table[12] == 479001600);
}

var array: [SIZE]i32 = @splat(0);
var res: i32 = 0;

export fn main() void {
    _ = std.c.printf("fact.zig\n");
    _ = std.c.printf("Calculates factorials (1000 iterations)\n");

    res = 0;
    for (0..SIZE) |j| array[j] = 0;

    var i: c_int = 0;
    while (i < N_ITER) : (i += 1) {
        for (0..SIZE) |j| array[j] +%= fact_table[j];
    }
    for (0..SIZE) |j| res +%= array[j];

    _ = std.c.printf("res=%ld", res);
    if (res == EXPECTED) {
        _ = std.c.printf(" [OK]\n");
    } else {
        _ = std.c.printf(" [FAIL] - expected %ld\n", EXPECTED);
    }
}
