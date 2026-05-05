// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0

pub const panic = @import("mos_panic");

const cpm = @import("cpm");

pub export fn main() callconv(.c) void {
    cpm.cpm_printstring("Hello, CP/M-65!\r\n$");
}
