//! MEGA65 plasma: full-screen interference pattern using a VIC-IV custom charset.
//! Runs at 3.5 MHz (C65 FAST mode); charset generated from an XOR-shift PRNG + sine table.
const std = @import("std");
const mega65 = @import("mega65");

const COLS: usize = 80;
const ROWS: usize = 25;
/// Custom charset written to this address in chip RAM (bank 0).
const CHARSET_ADDRESS: u32 = 0x3000;
/// Screen RAM address.
const SCREEN_ADDRESS: u32 = 0x0800;

/// VIC-IV register file mapped at $D000.
const vic: *volatile mega65.__vic4 = @ptrFromInt(0xd000);

/// 256-entry cyclic sine table (0x00–0xFF range).
const sine_table: [256]u8 = .{
    0x80, 0x7d, 0x7a, 0x77, 0x74, 0x70, 0x6d, 0x6a, 0x67, 0x64, 0x61, 0x5e,
    0x5b, 0x58, 0x55, 0x52, 0x4f, 0x4d, 0x4a, 0x47, 0x44, 0x41, 0x3f, 0x3c,
    0x39, 0x37, 0x34, 0x32, 0x2f, 0x2d, 0x2b, 0x28, 0x26, 0x24, 0x22, 0x20,
    0x1e, 0x1c, 0x1a, 0x18, 0x16, 0x15, 0x13, 0x11, 0x10, 0x0f, 0x0d, 0x0c,
    0x0b, 0x0a, 0x08, 0x07, 0x06, 0x06, 0x05, 0x04, 0x03, 0x03, 0x02, 0x02,
    0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x02, 0x02, 0x03,
    0x03, 0x04, 0x05, 0x06, 0x06, 0x07, 0x08, 0x0a, 0x0b, 0x0c, 0x0d, 0x0f,
    0x10, 0x11, 0x13, 0x15, 0x16, 0x18, 0x1a, 0x1c, 0x1e, 0x20, 0x22, 0x24,
    0x26, 0x28, 0x2b, 0x2d, 0x2f, 0x32, 0x34, 0x37, 0x39, 0x3c, 0x3f, 0x41,
    0x44, 0x47, 0x4a, 0x4d, 0x4f, 0x52, 0x55, 0x58, 0x5b, 0x5e, 0x61, 0x64,
    0x67, 0x6a, 0x6d, 0x70, 0x74, 0x77, 0x7a, 0x7d, 0x80, 0x83, 0x86, 0x89,
    0x8c, 0x90, 0x93, 0x96, 0x99, 0x9c, 0x9f, 0xa2, 0xa5, 0xa8, 0xab, 0xae,
    0xb1, 0xb3, 0xb6, 0xb9, 0xbc, 0xbf, 0xc1, 0xc4, 0xc7, 0xc9, 0xcc, 0xce,
    0xd1, 0xd3, 0xd5, 0xd8, 0xda, 0xdc, 0xde, 0xe0, 0xe2, 0xe4, 0xe6, 0xe8,
    0xea, 0xeb, 0xed, 0xef, 0xf0, 0xf1, 0xf3, 0xf4, 0xf5, 0xf6, 0xf8, 0xf9,
    0xfa, 0xfa, 0xfb, 0xfc, 0xfd, 0xfd, 0xfe, 0xfe, 0xfe, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff, 0xfe, 0xfe, 0xfe, 0xfd, 0xfd, 0xfc, 0xfb, 0xfa,
    0xfa, 0xf9, 0xf8, 0xf6, 0xf5, 0xf4, 0xf3, 0xf1, 0xf0, 0xef, 0xed, 0xeb,
    0xea, 0xe8, 0xe6, 0xe4, 0xe2, 0xe0, 0xde, 0xdc, 0xda, 0xd8, 0xd5, 0xd3,
    0xd1, 0xce, 0xcc, 0xc9, 0xc7, 0xc4, 0xc1, 0xbf, 0xbc, 0xb9, 0xb6, 0xb3,
    0xb1, 0xae, 0xab, 0xa8, 0xa5, 0xa2, 0x9f, 0x9c, 0x99, 0x96, 0x93, 0x90,
    0x8c, 0x89, 0x86, 0x83,
};

/// XOR-shift PRNG — no stdlib dependency needed.
var prng: u32 = 1;

fn rand8() u8 {
    prng ^= prng << 13;
    prng ^= prng >> 17;
    prng ^= prng << 5;
    return @truncate(prng);
}

/// Per-frame sine phase counters for Y and X axes.
var y_phase1: u8 = 0;
var y_phase2: u8 = 0;
var x_phase1: u8 = 0;
var x_phase2: u8 = 0;

/// Build 256 custom characters at CHARSET_ADDRESS using random dithering weighted by sine.
fn generate_charset() void {
    const charset: [*]volatile u8 = @ptrFromInt(CHARSET_ADDRESS);
    const bits = [_]u8{ 1, 2, 4, 8, 16, 32, 64, 128 };
    for (sine_table, 0..) |threshold, c| {
        for (0..8) |row| {
            var pattern: u8 = 0;
            for (bits) |bit| {
                if (rand8() > threshold) pattern |= bit;
            }
            charset[c * 8 + row] = pattern;
        }
    }
}

/// Unlock VIC-IV extended registers (required before accessing charptr etc.).
fn unlock_vic4() void {
    const key: *volatile u8 = @ptrFromInt(0xd02f);
    key.* = 0x47;
    key.* = 0x53;
}

/// Switch to 3.5 MHz C65 FAST mode (no VFAST).
fn speed_mode3() void {
    vic.ctrlb |= 0x40;           // VIC3_FAST_MASK
    vic.ctrlc &= ~@as(u8, 0x40); // clear VIC4_VFAST_MASK
}

/// Advance phase counters and write one frame of the interference pattern to screen RAM.
fn draw() void {
    const screen: [*]volatile u8 = @ptrFromInt(SCREEN_ADDRESS);
    var xbuf: [COLS]u8 = undefined;
    var ybuf: [ROWS]u8 = undefined;

    var ya = y_phase1;
    var yb = y_phase2;
    for (&ybuf) |*y| {
        y.* = sine_table[ya] +% sine_table[yb];
        ya +%= 4;
        yb +%= 9;
    }
    y_phase1 +%= 3;
    y_phase2 -%= 5;

    var xa = x_phase1;
    var xb = x_phase2;
    for (&xbuf) |*x| {
        x.* = sine_table[xa] +% sine_table[xb];
        xa +%= 3;
        xb +%= 7;
    }
    x_phase1 +%= 2;
    x_phase2 -%= 3;

    for (ybuf, 0..) |y, row| {
        for (xbuf, 0..) |x, col| {
            screen[row * COLS + col] = x +% y;
        }
    }
}

export fn main() void {
    unlock_vic4();
    generate_charset();
    // VIC-IV charptr register is at offset $68 from $D000 (= $D068).
    const charptr_reg: *volatile u32 = @ptrFromInt(0xd068);
    charptr_reg.* = CHARSET_ADDRESS;
    speed_mode3();
    while (true) draw();
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}

/// Satisfy crt0's __zero_bss / compiler-generated memory ops (no C stdlib linked).
export fn __memset(dest: [*]u8, c: u32, n: usize) [*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) dest[i] = @truncate(c);
    return dest;
}

export fn memset(dest: [*]u8, c: c_int, n: usize) [*]u8 {
    var i: usize = 0;
    while (i < n) : (i += 1) dest[i] = @truncate(@as(c_uint, @bitCast(c)));
    return dest;
}

export fn memcpy(noalias dest: [*]u8, noalias src: [*]const u8, n: usize) [*]u8 {
    @memcpy(dest[0..n], src[0..n]);
    return dest;
}

export fn memmove(dest: [*]u8, src: [*]const u8, n: usize) [*]u8 {
    if (@intFromPtr(dest) < @intFromPtr(src)) {
        var i: usize = 0;
        while (i < n) : (i += 1) dest[i] = src[i];
    } else {
        var i: usize = n;
        while (i > 0) {
            i -= 1;
            dest[i] = src[i];
        }
    }
    return dest;
}
