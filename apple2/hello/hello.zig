const appleIO = @cImport(@cInclude("apple-ii-io.h"));

export fn main() void {
    srand(1);
    // hires_clear();
    // appleIO.APPLEII_HIRES_ON.* = 0;
    // appleIO.APPLEII_MIXEDMODE_OFF.* = 0;
    // appleIO.APPLEII_PAGE_PAGE2.* = 0;
    // appleIO.APPLEII_TEXTMODE_GRAPHICS.* = 0;
    var sx = rand() % 280;
    var sy = rand() % 192;
    while (true) {
        const attractor: u64 = rand() % 3;
        var ax: u64 = 0;
        var ay: u64 = 0;
        switch (attractor) {
            0 => {
                ax = 0;
                ay = 192;
            },
            1 => {
                ax = 280;
                ay = 192;
            },
            2 => {
                ax = 140;
                ay = 0;
            },
            else => {},
        }
        sx = (sx + ax) / 2;
        sy = (sy + ay) / 2;
        // hires_plot_on(sx, sy);
    }
}
const std = @import("std");

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // override (default) panic handler
}

var next: u64 = 1;

fn rand() u64 {
    next = next * @as(u64, 1103515245) + @as(u64, 12345);
    return (next / @as(u64, 65536)) % @as(u64, 32768);
}

fn srand(seed: u64) void {
    next = seed;
}
