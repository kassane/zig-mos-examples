// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Commander X16 picolibc demo: exercises compare/scan from picolibc.
pub const panic = @import("mos_panic");

const cbm = @import("cbm");
const pc = @import("picolibc");

fn writeStr(s: []const u8) void {
    for (s) |c| cbm.cbm_k_chrout(c);
}

fn writeResult(label: []const u8, ok: bool) void {
    writeStr(label);
    writeStr(if (ok) "OK" else "FAIL");
    cbm.cbm_k_chrout('\r');
}

export fn main() void {
    // strncmp: first 3 chars equal, full strings differ.
    const pre = pc.strncmp("abcXX", "abcYY", 3);
    const full = pc.strncmp("abcXX", "abcYY", 5);
    writeResult("NCMP=", pre == 0 and full != 0);

    // strchr: locate 'l' in "picolibc"; NUL search returns end pointer.
    const hit = pc.strchr("picolibc", 'l');
    const miss = pc.strchr("picolibc", 'z');
    writeResult("CHR=", hit != null and miss == null);
}
