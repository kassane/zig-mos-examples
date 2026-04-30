// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES hello-world: demonstrates the nesdoug vram_buffer for deferred, mixed-mode writes.
pub const panic = @import("mos_panic");
const neslib = @import("neslib");
const nesdoug = @import("nesdoug");

const bg_palette: [16]u8 = .{ 0x0f, 0x00, 0x10, 0x30 } ++ .{0x00} ** 12;
const message: [12]u8 = .{ 'H', 'E', 'L', 'L', 'O', ' ', 'W', 'O', 'R', 'L', 'D', '!' };

pub export fn main() callconv(.c) void {
    neslib.ppu_on_all();
    neslib.pal_bg(&bg_palette);
    neslib.ppu_wait_nmi();

    nesdoug.set_vram_buffer();

    nesdoug.one_vram_buffer('A', neslib.NTADR_A(2, 3));
    nesdoug.one_vram_buffer('B', neslib.NTADR_A(5, 6));

    const addr = nesdoug.get_ppu_addr(0, 0x38, 0xc0);
    nesdoug.one_vram_buffer('C', addr);

    nesdoug.multi_vram_buffer_horz(&message, message.len, neslib.NTADR_A(10, 7));
    nesdoug.multi_vram_buffer_horz(&message, message.len, neslib.NTADR_A(12, 12));
    nesdoug.multi_vram_buffer_horz(&message, message.len, neslib.NTADR_A(14, 17));
    nesdoug.multi_vram_buffer_vert(&message, message.len, neslib.NTADR_A(10, 7));

    neslib.ppu_wait_nmi();
    while (true) {}
}
