//! mos-sim hello-world: direct MMIO I/O and the simulator's cycle counter.
//! Run with: mos-sim zig-out/bin/sim-hello
//!
//! Simulator memory-mapped I/O (see mos-sim --help):
//!   $FFF0 (4 bytes): read → clock cycles; write → reset counter
//!   $FFF8 (1 byte):  write → exit with code
//!   $FFF9 (1 byte):  write → character to stdout

const STDOUT: *volatile u8 = @ptrFromInt(0xFFF9);
const EXIT: *volatile u8 = @ptrFromInt(0xFFF8);
/// Low 16 bits of the 32-bit cycle counter at $FFF0.
const CLOCK_LO: *volatile u16 = @ptrFromInt(0xFFF0);

fn writeChar(c: u8) void {
    STDOUT.* = c;
}

fn writeStr(s: []const u8) void {
    for (s) |c| writeChar(c);
}

/// Print a u16 decimal without division — uses successive subtraction.
fn writeU16(v: u16) void {
    const powers = [_]u16{ 10000, 1000, 100, 10, 1 };
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

export fn main() void {
    writeStr("Hello from mos-sim!\n");
    CLOCK_LO.* = 0; // reset cycle counter
    const result = fib(20);
    const cycles = CLOCK_LO.*;
    writeStr("fib(20) = ");
    writeU16(result);
    writeStr("  (");
    writeU16(cycles);
    writeStr(" cycles)\n");
    EXIT.* = 0;
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
export fn __memset(dest: [*]u8, c: u32, n: usize) [*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) dest[i] = @truncate(c);
    return dest;
}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    EXIT.* = 1;
    while (true) {}
}
