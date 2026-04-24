// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES hello-world: demonstrates the VRAM update queue for bulk and non-sequential writes.
const neslib = @import("neslib");

const bg_palette: [16]u8 = .{ 0x0f, 0x00, 0x10, 0x30 } ++ .{0x00} ** 12;

pub export fn main() callconv(.c) void {
    // Sequential VRAM packet: writes "HELLO WORLD!" horizontally at tile (10, 14).
    const text_update: [16]u8 = .{
        neslib.MSB(neslib.NTADR_A(10, 14)) | neslib.NT_UPD_HORZ,
        neslib.LSB(neslib.NTADR_A(10, 14)),
        12,
        'H', 'E', 'L', 'L', 'O', ' ', 'W', 'O', 'R', 'L', 'D', '!',
        neslib.NT_UPD_EOF,
    };

    // Non-sequential packet: places 'A' and 'B' at two separate nametable positions.
    const two_letters: [7]u8 = .{
        neslib.MSB(neslib.NTADR_A(8, 17)), neslib.LSB(neslib.NTADR_A(8, 17)), 'A',
        neslib.MSB(neslib.NTADR_A(18, 5)), neslib.LSB(neslib.NTADR_A(18, 5)), 'B',
        neslib.NT_UPD_EOF,
    };

    neslib.ppu_off();
    neslib.pal_bg(&bg_palette);
    neslib.ppu_on_all();

    neslib.set_vram_update(&text_update);
    neslib.ppu_wait_nmi();

    neslib.set_vram_update(&two_letters);
    neslib.ppu_wait_nmi();

    neslib.set_vram_update(null);
    while (true) {}
}
