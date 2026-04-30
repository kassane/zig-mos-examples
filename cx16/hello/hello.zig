// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Commander X16 hello demo.
//! Uses the cbm module to print "HELLO X16!" via cbm_k_chrout,
//! then cycles the VIC border colour register.
pub const panic = @import("mos_panic");

const cbm = @import("cbm");

const VIC_BORDERCOL: *volatile u8 = @ptrFromInt(0xD020);

export fn main() void {
    const msg = "HELLO X16!\r";
    for (msg) |c| {
        cbm.cbm_k_chrout(c);
    }
    while (true) {
        VIC_BORDERCOL.* +%= 1;
    }
}
