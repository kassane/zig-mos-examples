// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 picolibc demo: exercises string building from picolibc.
//! Theme unique to this target: strcpy / strcat / strlen, printed via printf.
pub const panic = @import("mos_panic");
const pc = @import("picolibc");

var buf: [16]u8 = undefined;

export fn main() void {
    _ = pc.strcpy(&buf, "pico");
    _ = pc.strcat(&buf, "libc");
    _ = stdc.printf("%s\n", &buf);

    const n: c_int = @intCast(pc.strlen(&buf));
    _ = stdc.printf("strlen=");
    _ = stdc.printf("%d\n", n);
}

const stdc = @import("std").c;
