// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! PC Engine color-cycle demo.
//! Writes a cycling 9-bit color to VCE palette entry 0 (background color).
//! VCE registers: COLOR_INDEX at 0x0400, COLOR_DATA at 0x0402.

const IO_VCE_COLOR_INDEX: *volatile u16 = @ptrFromInt(0x0402);
const IO_VCE_COLOR_DATA: *volatile u16 = @ptrFromInt(0x0404);

export fn main() void {
    var color: u16 = 0;
    while (true) {
        IO_VCE_COLOR_INDEX.* = 0;
        IO_VCE_COLOR_DATA.* = color & 0x1FF;
        color +%= 1;
    }
}

// Required interrupt handler stubs for PCE vector table (crt0.S declares them weak).
export fn irq_vdc() callconv(.c) void {}
export fn irq_timer() callconv(.c) void {}
export fn nmi() callconv(.c) void {}
export fn irq_ext() callconv(.c) void {}
export fn irq_vdc_2() callconv(.c) void {}

pub fn panic(_: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
