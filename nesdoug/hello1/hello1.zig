const neslib = @import("neslib.zig");

pub export fn main() callconv(.C) void {
    const text = "Hello Zig!";
    const palette: [15]u8 = .{
        0x0f,
        0x00,
        0x10,
        0x30,
    } ++ [1]u8{0} ** 11;

    // screen off
    neslib.ppu_off();
    // load the BG palette
    neslib.pal_bg(&palette);
    // set a starting point on the screen
    neslib.vram_adr(neslib.NTADR_A(10, 14)); // screen is 32 x 30 tiles

    // this pushes 1 char to the screen
    for (text[0.. :0]) |c| {
        neslib.vram_put(c);
    }
    // turn on screen
    neslib.ppu_on_all();

    while (true) {
        // infinite loop
        // game code can go here later.
    }
}
