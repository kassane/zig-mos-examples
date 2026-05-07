// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 Sieve of Eratosthenes benchmark: finds primes up to 16382 (10 iterations).
//! Zig feature: bool flags (vs C char); std.math.log2_int comptime validates that
//! SIZE = 2^k - 1; comptime assertions catch mis-configuration at build time.
pub const panic = @import("mos_panic");
const std = @import("std");

const SIZE: usize = 8191;
const N_ITER: c_int = 10;
const EXPECTED: c_uint = 1900;

// Comptime: SIZE must be 2^k - 1 (Mersenne form). std.math.log2_int computes k
// exactly for power-of-2 inputs; the assert then reconstructs SIZE and verifies.
// This catches accidental SIZE edits that would break the benchmark contract.
comptime {
    const k = std.math.log2_int(usize, SIZE + 1);
    std.debug.assert((@as(usize, 1) << k) - 1 == SIZE);
}

// bool instead of u8: more expressive (true/false vs 0/1), identical memory layout
// on MOS (1 byte per element in [N]bool). Eliminates the != 0 comparisons.
var flags: [SIZE]bool = @splat(false);
var prime_count: c_uint = 0;

fn sieve(n: usize) c_uint {
    @setRuntimeSafety(false);
    var count: c_uint = 1;
    for (0..n) |k| flags[k] = true;
    for (0..n) |i| {
        if (flags[i]) {
            const prime: usize = i + i + 3;
            var k: usize = i + prime;
            while (k < n) : (k += prime) flags[k] = false;
            count +%= 1;
        }
    }
    return count;
}

export fn main() void {
    _ = std.c.printf("sieve.zig\n");
    _ = std.c.printf("Calculates the primes from 1 to 16382 (10 iterations)\n");

    var i: c_int = 0;
    while (i < N_ITER) : (i += 1) prime_count = sieve(SIZE);

    _ = std.c.printf("count=%u", prime_count);
    if (prime_count == EXPECTED) {
        _ = std.c.printf(" [OK]\n");
    } else {
        _ = std.c.printf(" [FAIL] - expected %u\n", EXPECTED);
    }
}
