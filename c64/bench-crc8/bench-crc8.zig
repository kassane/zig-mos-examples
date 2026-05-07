// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 CRC-8/GSM-A benchmark: computes CRC8 of the C64 Kernal ROM ($E000–$FFFF).
pub const panic = @import("mos_panic");
const std = @import("std");

// Comptime-typed benchmark dispatcher: same function body works for any CRC algorithm.
// `comptime Crc: type` is instantiated once per distinct type at compile time.
fn runCrc(comptime Crc: type, comptime expected: u8, data: []const u8) void {
    const crc = Crc.hash(data);
    _ = std.c.printf("CRC8=%02X", @as(c_uint, crc));
    if (crc == expected) {
        _ = std.c.printf(" [OK]\n");
    } else {
        _ = std.c.printf(" [FAIL] - expected %02X\n", @as(c_uint, expected));
    }
}

const Crc8GsmA = std.hash.crc.Crc8GsmA;

// Comptime self-test: Crc8GsmA.hash runs entirely in the Zig compiler's
// comptime interpreter — the table lookup and reduction happen at build time.
comptime {
    const probe: [4]u8 = .{ 0xC6, 0x42, 0x00, 0xFF };
    _ = Crc8GsmA.hash(&probe); // proves the algorithm is comptime-evaluable
}

const kernal_base: usize = 0xe000; // comptime-known C64 Kernal ROM address
const kernal_len: usize = 0x2000;
const EXPECTED_CRC: u8 = 0xa2;

export fn main() void {
    const kernal: [*]const u8 = @ptrFromInt(kernal_base);
    _ = std.c.printf("crc8.zig\n");
    _ = std.c.printf("Calculates the CRC8 of the C64 Kernal\n");
    runCrc(Crc8GsmA, EXPECTED_CRC, kernal[0..kernal_len]);
}
