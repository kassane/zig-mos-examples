// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! MEGA65 hello: prints to stdio and sets the border/screen colour via VIC-IV registers.
pub const panic = @import("mos_panic");
const std = @import("std");
const mega65 = @import("mega65");

/// 28-bit flat-memory byte access provided by mega65-libc (via DMA engine).
extern fn lpoke(address: u32, value: u8) void;
extern fn lpeek(address: u32) u8;

/// VIC-IV register file mapped at $D000.
const vic: *volatile mega65.__vic4 = @ptrFromInt(0xd000);

export fn main() void {
    _ = std.c.printf("Hello World!\n");
    vic.bordercol = 5; // green border
    lpoke(0x40000, 0); // write 0 to Attic RAM $40000
    vic.screencol = lpeek(0x40000); // read it back → black screen
}
