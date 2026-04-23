//! NES colour-cycle: advances the universal background colour through all 64 palette entries.
const neslib = @import("neslib");

pub export fn main() callconv(.c) void {
    neslib.ppu_off();
    neslib.pal_bg(&(.{0x0f} ** 16));
    neslib.ppu_on_bg();

    var color: u8 = 0;
    while (true) {
        for (0..30) |_| neslib.ppu_wait_nmi(); // ~0.5 s at 60 Hz NTSC
        color = (color +% 1) & 0x3f; // wrap within the 64 valid NES palette entries
        neslib.pal_col(0, color);
    }
}
