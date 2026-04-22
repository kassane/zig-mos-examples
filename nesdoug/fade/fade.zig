const neslib = @import("neslib");

const bg_palette: [16]u8 = .{
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
};

const message = "PALETTE FADE DEMO";

export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bg(&bg_palette);

    neslib.vram_adr(neslib.NTADR_A(7, 14));
    for (message) |c| neslib.vram_put(c);

    neslib.pal_bright(0);
    neslib.ppu_on_all();

    while (true) {
        // Fade in: brightness 0 (black) → 4 (normal)
        var b: u8 = 0;
        while (b <= 4) : (b += 1) {
            neslib.pal_bright(b);
            neslib.delay(6);
        }
        neslib.delay(60);
        // Fade out: brightness 4 (normal) → 0 (black)
        b = 4;
        while (true) {
            neslib.pal_bright(b);
            neslib.delay(6);
            if (b == 0) break;
            b -= 1;
        }
        neslib.delay(30);
    }
}
