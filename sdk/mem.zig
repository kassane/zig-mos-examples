// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Strong __memset / memset for MOS 6502/65816 platforms.
//!
//! zig cc (clang 21) compiles mem.c's __attribute__((weak)) __memset into a
//! broken recursive stub on MOS targets.  This object — compiled by the Zig
//! frontend through LLVM-MOS — generates a correct byte-store loop instead.
//!
//! Volatile pointer writes prevent LLVM-MOS from pattern-matching the loop as
//! a memset idiom and replacing it with a recursive self-call.
//!
//! Must be a TRUE object (b.addObject + exe.root_module.addObject), NOT an
//! archive member; ld.lld archive extraction is symbol-driven and the weak
//! stub from mem.c wins if this lands inside a .a.

const builtin = @import("builtin");

comptime {
    if (builtin.cpu.arch != .mos)
        @compileError("sdk/mem.zig is for MOS targets only");
    @export(&__memset_impl, .{ .name = "__memset", .linkage = .strong });
    @export(&memset_impl, .{ .name = "memset", .linkage = .strong });
}

fn memset_impl(dest: ?[*]u8, c: u8, n: usize) callconv(.c) ?[*]u8 {
    @setRuntimeSafety(false);
    if (n != 0) {
        var d = dest.?;
        var i: usize = n;
        while (true) {
            @as(*volatile u8, @ptrCast(d)).* = c; // workaround: prevents from eating the loop body
            i -= 1;
            if (i == 0) break;
            d += 1;
        }
    }
    return dest;
}

// __memset(dest, c, n, dest_n) — clang's fortified memset variant.
// dest_n is the buffer capacity; no bounds-check on 6502/65816.
fn __memset_impl(dest: ?[*]u8, c: u8, n: usize, dest_n: usize) callconv(.c) ?[*]u8 {
    _ = dest_n;
    @setRuntimeSafety(false);
    if (n != 0) {
        var d = dest.?;
        var i: usize = n;
        while (true) {
            @as(*volatile u8, @ptrCast(d)).* = c;
            i -= 1;
            if (i == 0) break;
            d += 1;
        }
    }
    return dest;
}
