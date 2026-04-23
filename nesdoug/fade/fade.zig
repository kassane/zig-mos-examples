//! NES palette-fade demo: fades the screen in and out using pal_bright (0 = black, 4 = normal).
const neslib = @import("neslib");

const bg_palette: [16]u8 = .{
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
};

export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bg(&bg_palette);
    neslib.vram_adr(neslib.NTADR_A(7, 14));
    for ("PALETTE FADE DEMO") |c| neslib.vram_put(c);
    neslib.pal_bright(0);
    neslib.ppu_on_all();

    while (true) {
        var bright: u8 = 0;
        while (bright <= 4) : (bright += 1) {
            neslib.pal_bright(bright);
            neslib.delay(6);
        }
        neslib.delay(60);
        bright = 4;
        while (true) {
            neslib.pal_bright(bright);
            neslib.delay(6);
            if (bright == 0) break;
            bright -= 1;
        }
        neslib.delay(30);
    }
}
