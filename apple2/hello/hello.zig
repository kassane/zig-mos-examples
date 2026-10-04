// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Apple IIe ProDOS hello — port of llvm-mos-sdk PR #444
//! `test/apple2/compile/minimal.c`: print one line, then wait for a keypress.
pub const panic = @import("mos_panic");

const std = @import("std");

/// libc getchar(); forwards to the platform's __getchar (Monitor RDKEY).
extern "c" fn getchar() c_int;

pub export fn main() callconv(.c) void {
    _ = std.c.printf("hello, apple ii\n");
    _ = getchar();
}
