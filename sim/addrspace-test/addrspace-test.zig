// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! addrSpace (.zp) and ptrABIAlign feature test for MOS 6502 (sim target).
//!
//! Exercises:
//!   - addrspace(.zp) global variable declaration (linker places it in $00-$FF)
//!   - @sizeOf(*addrspace(.zp) u8) == 1  (ZP pointer is 8-bit on MOS)
//!   - @alignOf(*u8) == 1  (ptrABIAlign: MOS data layout p:16:8 → no alignment requirement)
//!   - @addrSpaceCast from .zp pointer to generic pointer and back
//!
//! Run with: mos-sim zig-out/bin/sim-addrspace-test

pub const panic = @import("mos_panic");

const sim_io = @import("sim_io");

fn reg() *volatile sim_io.struct__sim_reg {
    return sim_io.sim_reg_iface;
}

fn writeStr(s: []const u8) void {
    for (s) |c| reg().putchar = c;
}

fn writeOk(label: []const u8) void {
    writeStr("  [OK]   ");
    writeStr(label);
    writeStr("\n");
}

fn writeFail(label: []const u8) void {
    writeStr("  [FAIL] ");
    writeStr(label);
    writeStr("\n");
}

var pass_count: u8 = 0;
var fail_count: u8 = 0;

fn check(ok: bool, label: []const u8) void {
    if (ok) {
        pass_count += 1;
        writeOk(label);
    } else {
        fail_count += 1;
        writeFail(label);
    }
}

// ── Compile-time assertions (caught before the simulator runs) ────────────────
comptime {
    if (@sizeOf(*addrspace(.zp) u8) != 1)
        @compileError("ZP pointer must be 1 byte — patch addrSpacePtrBitWidth in Type.zig");
    if (@alignOf(*u8) != 1)
        @compileError("ptrABIAlign must be 1 for MOS targets (p:16:8 data layout)");
}

// ── Zero-page globals ─────────────────────────────────────────────────────────
// The linker places these in $00-$FF because of the addrspace(.zp) qualifier.
var zp_u8: u8 addrspace(.zp) = 0;
var zp_u16: u16 addrspace(.zp) = 0;

pub fn main() void {
    writeStr("addrSpace + ptrABIAlign tests\n");
    writeStr("=============================\n");

    // ── Test 1: ptrABIAlign — @alignOf(*u8) == 1 ─────────────────────────────
    // MOS data layout: p:16:8  (16-bit pointer, 8-bit ABI alignment → 1 byte).
    check(@alignOf(*u8) == 1, "ptrABIAlign: @alignOf(*u8) == 1");

    // ── Test 2: ZP pointer size — @sizeOf(*addrspace(.zp) u8) == 1 ───────────
    // ZP pointers fit in one byte (address range $00-$FF).
    check(@sizeOf(*addrspace(.zp) u8) == 1, "ZP ptr size: @sizeOf(*addrspace(.zp) u8) == 1");

    // ── Test 3: ZP variable write / read (u8) ────────────────────────────────
    zp_u8 = 0xAB;
    check(zp_u8 == 0xAB, "ZP u8 write/read");

    // ── Test 4: ZP variable write / read (u16) ───────────────────────────────
    zp_u16 = 0x1234;
    check(zp_u16 == 0x1234, "ZP u16 write/read");

    // ── Test 5: @addrSpaceCast ZP → generic ──────────────────────────────────
    // Taking the address of a .zp global gives *addrspace(.zp) u8.
    // Casting to *u8 (generic) must still read the same value.
    const gen_ptr: *u8 = @addrSpaceCast(&zp_u8);
    gen_ptr.* = 0x55;
    check(zp_u8 == 0x55, "@addrSpaceCast zp→generic write");

    // ── Test 6: @addrSpaceCast generic → ZP ──────────────────────────────────
    // gen_ptr already points into ZP; cast back and verify.
    const zp_ptr: *addrspace(.zp) u8 = @addrSpaceCast(gen_ptr);
    zp_ptr.* = 0x77;
    check(zp_u8 == 0x77, "@addrSpaceCast generic→zp write");

    // ── Summary ───────────────────────────────────────────────────────────────
    writeStr("-----------------------------\n");
    writeStr("pass: ");
    reg().putchar = '0' + pass_count;
    writeStr("  fail: ");
    reg().putchar = '0' + fail_count;
    writeStr("\n");

    reg().exit = if (fail_count == 0) @as(u8, 0) else @as(u8, 1);
}

// ── Required runtime stubs (no libc linked on sim) ───────────────────────────

export fn __memset(dest: [*]u8, c: u32, n: usize) [*]u8 {
    const byte: u8 = @truncate(c);
    const p: [*]volatile u8 = dest;
    var i: usize = 0;
    while (i < n) : (i += 1) p[i] = byte;
    return dest;
}

export fn abort() callconv(.c) noreturn {
    reg().exit = 1;
    while (true) {}
}
