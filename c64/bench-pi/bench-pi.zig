// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 Pi benchmark: computes ~160 digits of pi using the Spigot algorithm.
pub const panic = @import("mos_panic");
const std = @import("std");

const SCALE: i32 = std.math.powi(i32, 10, 4) catch 10000;
const ARRINIT: i32 = SCALE / 5;
const NUM_DIG: usize = 560;
const EXPECTED_CARRY: i32 = 2822;

// Comptime invariant checks — caught at compile time, zero runtime cost:
//   • NUM_DIG % 14 == 0  → Spigot inner loop always terminates on a clean boundary.
//   • ARRINIT < SCALE    → first accumulation step cannot overflow the leading digit.
//   • SCALE == 10_000    → four-digit decimal groups match the %04d format below.
comptime {
    std.debug.assert(NUM_DIG % 14 == 0);
    std.debug.assert(ARRINIT < SCALE);
    std.debug.assert(SCALE == std.math.powi(i32, 10, 4) catch @compileError("Wrong value!!"));
}

var carry: i32 = 0;
var arr: [NUM_DIG + 1]i32 = @splat(0);

fn pi_digits(digits: usize) void {
    @setRuntimeSafety(false);
    for (0..digits + 1) |i| arr[i] = ARRINIT;
    var i: usize = digits;
    while (i > 0) : (i -%= 14) {
        var sum: i32 = 0;
        var j: usize = i;
        while (j > 0) : (j -= 1) {
            sum = sum *% @as(i32, @intCast(j)) +% SCALE *% arr[j];
            arr[j] = @rem(sum, @as(i32, @intCast(j * 2 - 1)));
            sum = @divTrunc(sum, @as(i32, @intCast(j * 2 - 1)));
        }
        _ = std.c.printf("%04d", @as(c_int, carry +% @divTrunc(sum, SCALE)));
        carry = @rem(sum, SCALE);
        if (i < 14) break;
    }
}

export fn main() void {
    _ = std.c.printf("pi.zig\n");
    _ = std.c.printf("Calculates pi digits\n");

    pi_digits(NUM_DIG);

    _ = std.c.printf("\ncarry=%ld", carry);
    if (carry == EXPECTED_CARRY) {
        _ = std.c.printf(" [OK]\n");
    } else {
        _ = std.c.printf(" [FAIL] - expected %ld\n", EXPECTED_CARRY);
    }
}
