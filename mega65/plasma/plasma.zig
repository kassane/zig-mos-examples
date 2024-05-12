//! WIP: port based on https://github.com/llvm-mos/llvm-mos-sdk/blob/main/examples/mega65/plasma.cc

const std = @import("std");
const mega65 = @cImport({
    @cInclude("mega65.h");
    // @compileError("unable to translate C expr: unexpected token 'volatile'");
    @cDefine("VICIV", "");
});
// FIXME
const VICIV = @as(*mega65.__vic4, std.zig.c_translation.promoteIntLiteral(c_int, 0xd000, .hex)).*;

const RandomXORS = extern struct {
    const state: u32 = 7;

    pub fn rand8() u8 {
        return @intCast(rand32() & 0xff);
    }
    pub fn rand32() u32 {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return state;
    }
};

/// Sets MEGA65 speed to 3.5 Mhz
export fn speed_mode3() void {
    VICIV.ctrlb |= mega65.VIC3_FAST_MASK;
    VICIV.ctrlc &= ~mega65.VIC4_VFAST_MASK;
}

/// Cyclic sine lookup table
const sine_table = [256]u8{
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

/// Generate charset with 8 * 256 characters at given address
export fn make_charset(charset_address: u16, rng: *RandomXORS) void {
    const charset = @as(*u8, @ptrCast(&charset_address));
    for (sine_table) |sine| {
        for (0..7) |_| {
            charset.* = (struct {
                pub fn init(s: u8) u8 {
                    var pattern: u8 = 0;
                    const bits = [8]u8{ 1, 2, 4, 8, 16, 32, 64, 128 };
                    for (bits) |bit| {
                        if (rng.rand8() > s) {
                            pattern |= bit;
                        }
                    }
                    return pattern;
                }
            }).init(sine);
        }
    }
}

/// Plasma - duckType
fn Plasma(comptime cols: usize, comptime rows: usize) type {
    return struct {
        pub fn init(charset_address: u16, rng: *RandomXORS) @This() {
            make_charset(charset_address, rng);
            VICIV.charptr = charset_address;
        }

        pub fn update(self: @This()) void {
            var i = self.y_cnt1;
            var j = self.y_cnt2;
            for (self.ydata) |y| {
                y = sine_table[i] + sine_table[j];
                i += 4;
                j += 9;
            }
            i = self.x_cnt1;
            j = self.x_cnt2;
            for (self.xdata) |*x| {
                x = sine_table[i] + sine_table[j];
                i += 3;
                j += 7;
            }
            self.x_cnt1 += 2;
            self.x_cnt2 -= 3;
            self.y_cnt1 += 3;
            self.y_cnt2 -= 5;

            write_to_screen();
        }

        // Write summed buffers to screen memory
        pub fn write_to_screen(self: @This()) void {
            const screen_ptr = @as(*u8, &mega65.DEFAULT_SCREEN);
            for (self.ydata) |y| {
                for (self.xdata) |x| {
                    screen_ptr.* = y + x;
                }
            }
        }

        ydata: [rows]u8 = std.mem.zeroes([rows]u8),
        xdata: [cols]u8 = std.mem.zeroes([cols]u8),

        x_cnt1: u8 = 0,
        x_cnt2: u8 = 0,
        y_cnt1: u8 = 0,
        y_cnt2: u8 = 0,
    };
}

export fn main() void {
    const COLS: usize = 80;
    const ROWS: usize = 25;
    const CHARSET_ADDRESS: u16 = 0x3000;
    var rng: RandomXORS = .{};
    const plasma = Plasma(COLS, ROWS).init(CHARSET_ADDRESS, &rng);
    speed_mode3();
    while (true) {
        plasma.update();
    }
}