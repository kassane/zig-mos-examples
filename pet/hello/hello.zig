// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
pub const panic = @import("mos_panic");
const cbm = @import("cbm");

pub export fn main() callconv(.c) void {
    const msg = "HELLO PET!\r";
    for (msg) |c| cbm.cbm_k_chrout(c);
    while (true) {}
}
