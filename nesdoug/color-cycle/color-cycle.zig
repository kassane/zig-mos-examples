// Port of llvm-mos-sdk examples/nes/color-cycle.c
// Cycles the NES universal background colour through all 64 palette entries.
const neslib = @import("neslib");

pub export fn main() callconv(.c) void {
    const bg_palette: [16]u8 = .{0x0f} ++ [1]u8{0x0f} ** 15;
    neslib.ppu_off();
    neslib.pal_bg(&bg_palette);
    neslib.ppu_on_bg();

    var color: u8 = 0;
    while (true) {
        // Hold each colour for ~0.5 s (30 frames at 60 Hz NTSC)
        var frame: u8 = 0;
        while (frame < 30) : (frame += 1) {
            neslib.ppu_wait_nmi();
        }
        color = (color +% 1) & 0x3f; // stay within the 64 valid NES colours
        neslib.pal_col(0, color);
    }
}
