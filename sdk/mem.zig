// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Strong __memset for MOS 6502/65816 platforms.
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
//!
//! NOTE: Do NOT export a strong `memset` here. The SDK's weak memset in mem.c
//! correctly casts `int c` to `char` before calling `__memset`. Exporting a
//! strong `memset` with `c: u8` breaks the MOS calling convention because
//! C's `int` is 16-bit on MOS (shifts the `n` argument to wrong registers).

const builtin = @import("builtin");

comptime {
    if (builtin.cpu.arch != .mos)
        @compileError("sdk/mem.zig is for MOS targets only");
    @export(&__memset_impl, .{ .name = "__memset", .linkage = .strong });
    @export(&abort_impl, .{ .name = "abort", .linkage = .strong });
}

// Bare-metal abort: halt the CPU.
// std.process.abort() lowers to C abort() for unknown OS tags (including
// MOS .nes/.snes). Debug builds pull this in transitively through
// std.debug.defaultPanic even when a custom panic handler is provided.
fn abort_impl() callconv(.c) noreturn {
    while (true) {}
}

// __memset(dest, c, n, dest_n) — clang's fortified memset variant.
// dest_n is the buffer capacity; no bounds-check on 6502/65816.
// Also satisfies the SDK's 3-param __memset(char*, char, size_t) calls
// since the 4th arg (dest_n) is ignored and the first 3 share the same ABI.
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
