// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Commander X16 picolibc demo: exercises string.h functions from picolibc.
pub const panic = @import("mos_panic");

const cbm = @import("cbm");
const pc = @import("picolibc");

fn writeStr(s: []const u8) void {
    for (s) |c| cbm.cbm_k_chrout(c);
}

fn writeU8(v: u8) void {
    if (v >= 10) writeU8(v / 10);
    cbm.cbm_k_chrout('0' + v % 10);
}

export fn main() void {
    const s = "picolibc";
    const n: u8 = @truncate(pc.strlen(s));
    writeStr("STRLEN=");
    writeU8(n);
    cbm.cbm_k_chrout('\r');

    const r: c_int = pc.strcmp("abc", "abc");
    writeStr("STRCMP=");
    writeU8(@intCast(r));
    cbm.cbm_k_chrout('\r');
}
