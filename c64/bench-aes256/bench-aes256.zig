// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! C64 AES-256-CBC benchmark: encrypts the C64 Kernal ROM ($E000–$FFFF) with AES-256-CBC,
//! then verifies the result with CRC-32/CKSUM. Pure Zig port of tiny-AES-c (public domain).
pub const panic = @import("mos_panic");
const std = @import("std");

const Crc32Cksum = std.hash.crc.Crc32Cksum;

// AES-256: Nk=8 key words, Nr=14 rounds, 240-byte expanded key.
const Nk: usize = 8;
const Nr: usize = 14;
const key_exp_size: usize = 240;

// S-box in ROM (const → .rodata on MOS).
const sbox: [256]u8 = .{
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
};

const Rcon: [11]u8 = .{ 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36 };

const aes_key: [32]u8 = .{
    0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe,
    0x2b, 0x73, 0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
    0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7,
    0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4,
};
const iv_init: [16]u8 = .{
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
};
const expected_crc: u32 = 0xff1ee2c1;

// Globals avoid large stack allocations on the MOS soft stack.
var round_key: [key_exp_size]u8 = @splat(0);
var buf: [0x2000]u8 = @splat(0);
var cbc_state: [4][4]u8 = @splat(@splat(0));
var cbc_iv: [16]u8 = @splat(0);

fn xtime(x: u8) u8 {
    @setRuntimeSafety(false);
    return (x << 1) ^ (((x >> 7) & 1) *% @as(u8, 0x1b));
}

fn keyExpansion(rk: *[key_exp_size]u8, key: *const [32]u8) void {
    @setRuntimeSafety(false);
    var tempa: [4]u8 = undefined;
    var i: usize = 0;
    while (i < Nk) : (i += 1) {
        rk[i * 4 + 0] = key[i * 4 + 0];
        rk[i * 4 + 1] = key[i * 4 + 1];
        rk[i * 4 + 2] = key[i * 4 + 2];
        rk[i * 4 + 3] = key[i * 4 + 3];
    }
    i = Nk;
    while (i < 4 * (Nr + 1)) : (i += 1) {
        const k = (i - 1) * 4;
        tempa[0] = rk[k + 0];
        tempa[1] = rk[k + 1];
        tempa[2] = rk[k + 2];
        tempa[3] = rk[k + 3];
        if (i % Nk == 0) {
            const u = tempa[0];
            tempa[0] = sbox[tempa[1]];
            tempa[1] = sbox[tempa[2]];
            tempa[2] = sbox[tempa[3]];
            tempa[3] = sbox[u];
            tempa[0] ^= Rcon[i / Nk];
        }
        if (i % Nk == 4) {
            tempa[0] = sbox[tempa[0]];
            tempa[1] = sbox[tempa[1]];
            tempa[2] = sbox[tempa[2]];
            tempa[3] = sbox[tempa[3]];
        }
        const j = i * 4;
        const m = (i - Nk) * 4;
        rk[j + 0] = rk[m + 0] ^ tempa[0];
        rk[j + 1] = rk[m + 1] ^ tempa[1];
        rk[j + 2] = rk[m + 2] ^ tempa[2];
        rk[j + 3] = rk[m + 3] ^ tempa[3];
    }
}

// state[col][row], matching tiny-AES-c's state_t[4][4] column-major layout.
fn addRoundKey(round: usize, state: *[4][4]u8, rk: *const [key_exp_size]u8) void {
    @setRuntimeSafety(false);
    var c: usize = 0;
    while (c < 4) : (c += 1) {
        var r: usize = 0;
        while (r < 4) : (r += 1) {
            state[c][r] ^= rk[round * 16 + c * 4 + r];
        }
    }
}

fn subBytes(state: *[4][4]u8) void {
    @setRuntimeSafety(false);
    var r: usize = 0;
    while (r < 4) : (r += 1) {
        var c: usize = 0;
        while (c < 4) : (c += 1) {
            state[c][r] = sbox[state[c][r]];
        }
    }
}

fn shiftRows(state: *[4][4]u8) void {
    @setRuntimeSafety(false);
    var temp: u8 = undefined;
    // row 1: shift left 1
    temp = state[0][1];
    state[0][1] = state[1][1];
    state[1][1] = state[2][1];
    state[2][1] = state[3][1];
    state[3][1] = temp;
    // row 2: shift left 2
    temp = state[0][2];
    state[0][2] = state[2][2];
    state[2][2] = temp;
    temp = state[1][2];
    state[1][2] = state[3][2];
    state[3][2] = temp;
    // row 3: shift left 3
    temp = state[0][3];
    state[0][3] = state[3][3];
    state[3][3] = state[2][3];
    state[2][3] = state[1][3];
    state[1][3] = temp;
}

fn mixColumns(state: *[4][4]u8) void {
    @setRuntimeSafety(false);
    var c: usize = 0;
    while (c < 4) : (c += 1) {
        const t = state[c][0];
        const tmp = state[c][0] ^ state[c][1] ^ state[c][2] ^ state[c][3];
        var tm: u8 = undefined;
        tm = xtime(state[c][0] ^ state[c][1]);
        state[c][0] ^= tm ^ tmp;
        tm = xtime(state[c][1] ^ state[c][2]);
        state[c][1] ^= tm ^ tmp;
        tm = xtime(state[c][2] ^ state[c][3]);
        state[c][2] ^= tm ^ tmp;
        tm = xtime(state[c][3] ^ t);
        state[c][3] ^= tm ^ tmp;
    }
}

fn cipher(state: *[4][4]u8, rk: *const [key_exp_size]u8) void {
    @setRuntimeSafety(false);
    addRoundKey(0, state, rk);
    var round: usize = 1;
    while (true) : (round += 1) {
        subBytes(state);
        shiftRows(state);
        if (round == Nr) break;
        mixColumns(state);
        addRoundKey(round, state, rk);
    }
    addRoundKey(Nr, state, rk);
}

fn cbcEncrypt(data: []u8, iv: *const [16]u8) void {
    @setRuntimeSafety(false);
    @memcpy(&cbc_iv, iv);
    var i: usize = 0;
    while (i < data.len) : (i += 16) {
        const block = data[i..][0..16];
        var j: usize = 0;
        while (j < 16) : (j += 1) block[j] ^= cbc_iv[j];
        // Unpack bytes into column-major state: cbc_state[col][row] = block[col*4+row].
        var c: usize = 0;
        while (c < 4) : (c += 1) {
            var r: usize = 0;
            while (r < 4) : (r += 1) cbc_state[c][r] = block[c * 4 + r];
        }
        cipher(&cbc_state, &round_key);
        c = 0;
        while (c < 4) : (c += 1) {
            var r: usize = 0;
            while (r < 4) : (r += 1) block[c * 4 + r] = cbc_state[c][r];
        }
        @memcpy(&cbc_iv, block);
    }
}

export fn main() void {
    _ = std.c.printf("aes256.zig\n");
    _ = std.c.printf("Encrypts the C64 Kernal with AES-256-CBC\n");

    const kernal: [*]const u8 = @ptrFromInt(0xe000);
    @memcpy(&buf, kernal[0..0x2000]);

    keyExpansion(&round_key, &aes_key);
    cbcEncrypt(&buf, &iv_init);

    const crc = Crc32Cksum.hash(&buf);
    _ = std.c.printf("CRC32=%08lX", crc);
    if (crc == expected_crc) {
        _ = std.c.printf(" [OK]\n");
    } else {
        _ = std.c.printf(" [FAIL] - expected %08lX\n", expected_crc);
    }
}
