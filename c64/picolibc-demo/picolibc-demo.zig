// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 picolibc demo: exercises string.h functions from picolibc.
pub const panic = @import("mos_panic");
const pc = @import("picolibc");

export fn main() void {
    const s = "picolibc";
    _ = stdc.printf("%s\n", s);
    const n: c_int = @intCast(pc.strlen(s));
    _ = stdc.printf("strlen=\"%d\"\n", n);

    const r: c_int = pc.strcmp("abc", "abc");
    _ = stdc.printf("strcmp=%d\n", r);
}

const stdc = @import("std").c;
