// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
pub const panic = @import("mos_panic");

// sv_sys_control_set is provided by supervision.c (in libc).
extern fn sv_sys_control_set(val: u8) void;

pub export fn main() callconv(.c) void {
    sv_sys_control_set(0); // disable NMI, timers, audio DMA, LCD
    while (true) {}
}
