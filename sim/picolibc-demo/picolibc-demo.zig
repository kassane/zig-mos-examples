// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! mos-sim picolibc demo: exercises the memory family from picolibc.
//! Theme unique to this target: memcpy / memcmp / memchr, verified at runtime
//! through the mos-sim putchar register.
//! Run with: mos-sim zig-out/bin/sim-picolibc-demo

pub const panic = @import("mos_panic");
const sim_io = @import("sim_io");
const pc = @import("picolibc");

fn reg() *volatile sim_io.struct__sim_reg {
    return sim_io.sim_reg_iface;
}

fn writeChar(c: u8) void {
    reg().putchar = c;
}

fn writeStr(s: []const u8) void {
    for (s) |c| writeChar(c);
}

pub fn main() void {
    // memcpy: copy a 4-byte payload and check the bytes landed.
    var dst: [4]u8 = undefined;
    _ = pc.memcpy(&dst, "ok!\x00", 4);
    if (dst[0] == 'o' and dst[1] == 'k' and dst[2] == '!') {
        writeStr("memcpy OK\n");
    } else {
        writeStr("memcpy FAIL\n");
    }

    // memcmp: equal vs differing buffers.
    const eq = pc.memcmp("abcd", "abcd", 4);
    const ne = pc.memcmp("abcd", "abce", 4);
    if (eq == 0 and ne != 0) {
        writeStr("memcmp OK\n");
    } else {
        writeStr("memcmp FAIL\n");
    }

    // memchr: locate a byte inside a buffer.
    const hit = pc.memchr("picolibc", 'l', 8);
    if (hit != null) {
        writeStr("memchr OK\n");
    } else {
        writeStr("memchr FAIL\n");
    }

    reg().exit = 0;
}

export fn abort() callconv(.c) noreturn {
    reg().exit = 1;
    while (true) {}
}

export fn __memset(dest: [*]u8, c: u32, n: usize) [*]u8 {
    const byte: u8 = @truncate(c);
    const p: [*]volatile u8 = dest;
    var i: usize = 0;
    while (i < n) : (i += 1) p[i] = byte;
    return dest;
}
