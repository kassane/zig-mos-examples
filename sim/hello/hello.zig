// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! mos-sim benchmarks: fib and sieve via typed MMIO (sim_io module).
//! Run with: mos-sim zig-out/bin/sim-hello
//!
//! Output format:
//!   mos-sim benchmarks
//!   ==================
//!   fib(10) = 55        ( XXX cycles)
//!   fib(20) = 6765      ( XXX cycles)
//!   sieve<127>: 31 primes  (XXXX cycles)

const sim_io = @import("sim_io");

fn reg() *volatile sim_io.struct__sim_reg {
    return sim_io.sim_reg_iface;
}

fn writeChar(c: u8) void {
    reg().putchar = c;
}

fn writeStr(s: []const u8) void {
    for (s) |c| writeChar(c);
}

/// Print a u16 decimal value right-justified in a field of `width` chars.
fn writeU16Padded(v: u16, width: u8) void {
    const powers = [_]u16{ 10000, 1000, 100, 10, 1 };
    // Count digits
    var digits: u8 = 1;
    if (v >= 10000) {
        digits = 5;
    } else if (v >= 1000) {
        digits = 4;
    } else if (v >= 100) {
        digits = 3;
    } else if (v >= 10) {
        digits = 2;
    }
    // Leading spaces
    if (digits < width) {
        var sp: u8 = 0;
        while (sp < width - digits) : (sp += 1) writeChar(' ');
    }
    // Digits
    var printed = false;
    var n = v;
    for (powers) |p| {
        var d: u8 = 0;
        while (n >= p) {
            n -= p;
            d += 1;
        }
        if (d != 0 or printed or p == 1) {
            writeChar('0' + d);
            printed = true;
        }
    }
}

fn writeU16(v: u16) void {
    writeU16Padded(v, 0);
}

fn resetClock() void {
    // Write any value to clock[0] to reset the counter.
    reg().clock[0] = 0;
}

fn readClock() u16 {
    const lo: u16 = reg().clock[0];
    const hi: u16 = reg().clock[1];
    return lo | (hi << 8);
}

fn fib(n: u8) u16 {
    var a: u16 = 0;
    var b: u16 = 1;
    var i: u8 = 0;
    while (i < n) : (i += 1) {
        const t = a +% b;
        a = b;
        b = t;
    }
    return a;
}

/// External linkage prevents the optimizer from constant-folding fib(n).
export var fib_n: u8 = 20;
export var fib_n10: u8 = 10;

var sieve: [128]u8 = undefined;

fn countPrimes() u8 {
    // Sieve of Eratosthenes for numbers < 128. sieve[i]==0 means prime.
    var i: u8 = 0;
    while (i < 128) : (i += 1) sieve[i] = 0;
    sieve[0] = 1;
    sieve[1] = 1;
    var p: u8 = 2;
    while (p < 128) : (p += 1) {
        if (sieve[p] == 0) {
            var mul: u16 = @as(u16, p) * @as(u16, p);
            while (mul < 128) : (mul += p) {
                sieve[@truncate(mul)] = 1;
            }
        }
    }
    var count: u8 = 0;
    var j: u8 = 0;
    while (j < 128) : (j += 1) {
        if (sieve[j] == 0) count += 1;
    }
    return count;
}

pub fn main() void {
    writeStr("mos-sim benchmarks\n");
    writeStr("==================\n");

    // fib(10)
    resetClock();
    const r10 = fib(fib_n10);
    const c10 = readClock();
    writeStr("fib(10) = ");
    writeU16Padded(r10, 6);
    writeStr("  (");
    writeU16Padded(c10, 4);
    writeStr(" cycles)\n");

    // fib(20)
    resetClock();
    const r20 = fib(fib_n);
    const c20 = readClock();
    writeStr("fib(20) = ");
    writeU16Padded(r20, 6);
    writeStr("  (");
    writeU16Padded(c20, 4);
    writeStr(" cycles)\n");

    // sieve<127>
    resetClock();
    const primes = countPrimes();
    const cs = readClock();
    writeStr("sieve<127>: ");
    writeU16(@as(u16, primes));
    writeStr(" primes  (");
    writeU16Padded(cs, 4);
    writeStr(" cycles)\n");

    reg().exit = 0;
}

/// Unsigned 16-bit division (compiler-rt builtin; libcrt.a is LLVM-23 bitcode, incompatible).
export fn __udivhi3(dividend: u16, divisor: u16) u16 {
    if (divisor == 0) return 0;
    var n = dividend;
    var d = divisor;
    var bit: u16 = 1;
    while (d <= n and d & 0x8000 == 0) {
        d <<= 1;
        bit <<= 1;
    }
    var q: u16 = 0;
    while (bit != 0) : (bit >>= 1) {
        if (n >= d) {
            n -= d;
            q |= bit;
        }
        d >>= 1;
    }
    return q;
}

/// Unsigned 16-bit modulo (compiler-rt builtin).
export fn __umodhi3(dividend: u16, divisor: u16) u16 {
    if (divisor == 0) return 0;
    var n = dividend;
    var d = divisor;
    while (d <= n and d & 0x8000 == 0) d <<= 1;
    while (d >= divisor) : (d >>= 1) {
        if (n >= d) n -= d;
    }
    return n;
}

/// Unsigned 16-bit multiply (compiler-rt builtin).
export fn __mulhi3(a: u16, b: u16) u16 {
    var result: u16 = 0;
    var x = a;
    var y = b;
    while (y != 0) : (y >>= 1) {
        if (y & 1 != 0) result +%= x;
        x +%= x;
    }
    return result;
}

/// Satisfy crt0's __zero_bss (no libc linked).
/// Uses volatile to prevent LLVM from lowering the loop into a __memset call (infinite recursion).
export fn __memset(dest: [*]u8, c: u32, n: usize) [*]u8 {
    const byte: u8 = @truncate(c);
    const p: [*]volatile u8 = dest;
    var i: usize = 0;
    while (i < n) : (i += 1) p[i] = byte;
    return dest;
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    reg().exit = 1;
    while (true) {}
}
