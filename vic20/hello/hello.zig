// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
pub const panic = @import("mos_panic");

const cbm = @import("cbm");

// VIC chip register: background + border colour (offset 15 from $9000)
const VIC_BG_BORDER: *volatile u8 = @ptrFromInt(0x900F);

pub export fn main() callconv(.c) void {
    const msg = "HELLO VIC20!\r";
    for (msg) |c| {
        cbm.cbm_k_chrout(c);
    }
    while (true) {
        VIC_BG_BORDER.* +%= 1;
    }
}
