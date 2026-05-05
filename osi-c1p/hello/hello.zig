// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0

pub const panic = @import("mos_panic");

pub export fn main() callconv(.c) void {
    _ = printf("Hello, OSI Challenger 1P!\n");
}

extern fn printf(fmt: [*:0]const u8, ...) c_int;
