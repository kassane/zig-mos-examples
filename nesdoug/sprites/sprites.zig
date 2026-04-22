const neslib = @import("neslib");

// Combined bg + spr palette (32 bytes).
// bg: black bg (0x0f), colour-3=white (0x30) for ASCII tiles
// spr palette 0: transparent(0x0f), white(0x30), orange(0x16), yellow(0x27)
const all_palette: [32]u8 = .{
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x00, 0x10, 0x30,
    0x0f, 0x30, 0x16, 0x27,
    0x0f, 0x30, 0x16, 0x27,
    0x0f, 0x30, 0x16, 0x27,
    0x0f, 0x30, 0x16, 0x27,
};

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_all(&all_palette);
    // Force sprites to use pattern table 0 ($0000) where Alpha.chr stores
    // the ASCII glyphs.  Must be set before ppu_on_all so PPUCTRL picks it up.
    neslib.bank_spr(0);
    neslib.ppu_on_all();
    // Wait one full NMI so the NMI handler applies the PPUCTRL/bank settings.
    neslib.ppu_wait_nmi();

    var x: u8 = 120;
    var y: u8 = 112;
    var vx: i8 = 1;
    var vy: i8 = 1;

    while (true) {
        neslib.ppu_wait_nmi();
        neslib.oam_clear();

        if (x >= 232) vx = -1;
        if (x <= 8) vx = 1;
        if (y >= 216) vy = -1;
        if (y <= 8) vy = 1;
        x = @intCast(@as(i16, x) + vx);
        y = @intCast(@as(i16, y) + vy);

        // Two side-by-side sprites using confirmed-good tile indices
        neslib.oam_spr(x, y, 'Z', 0x00);
        neslib.oam_spr(x +% 8, y, 'I', 0x00);
    }
}
