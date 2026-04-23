//! NES controller demo: two sprites controlled by P1 and P2; background flashes on collision.
const neslib = @import("neslib");

/// NES controller button bit-masks returned by `pad_poll`.
const Pad = struct {
    const right:  u8 = 0x01;
    const left:   u8 = 0x02;
    const down:   u8 = 0x04;
    const up:     u8 = 0x08;
    const start:  u8 = 0x10;
    const select: u8 = 0x20;
    const b_btn:  u8 = 0x40;
    const a_btn:  u8 = 0x80;
};

/// True when two sprite coordinates (same axis) are within one tile of each other.
fn overlaps(a: u8, b: u8) bool {
    const d: i16 = @as(i16, a) - @as(i16, b);
    return d > -8 and d < 8;
}

export fn main() callconv(.c) void {
    const bg_palette: [16]u8 = .{
        0x0f, 0x00, 0x10, 0x30,
        0x0f, 0x00, 0x10, 0x30,
        0x0f, 0x00, 0x10, 0x30,
        0x0f, 0x00, 0x10, 0x30,
    };
    const spr_palette: [16]u8 = .{
        0x0f, 0x16, 0x27, 0x30, // P1: orange
        0x0f, 0x09, 0x19, 0x30, // P2: green
        0x0f, 0x16, 0x27, 0x30,
        0x0f, 0x16, 0x27, 0x30,
    };

    neslib.ppu_off();
    neslib.pal_bg(&bg_palette);
    neslib.pal_spr(&spr_palette);
    neslib.bank_spr(0);
    neslib.ppu_on_all();

    var x1: u8 = 80;
    var y1: u8 = 120;
    var x2: u8 = 176;
    var y2: u8 = 120;

    while (true) {
        neslib.ppu_wait_nmi();

        const p1 = neslib.pad_poll(0);
        const p2 = neslib.pad_poll(1);

        if (p1 & Pad.up    != 0 and y1 > 8)   y1 -= 2;
        if (p1 & Pad.down  != 0 and y1 < 224) y1 += 2;
        if (p1 & Pad.left  != 0 and x1 > 8)   x1 -= 2;
        if (p1 & Pad.right != 0 and x1 < 248) x1 += 2;

        if (p2 & Pad.up    != 0 and y2 > 8)   y2 -= 2;
        if (p2 & Pad.down  != 0 and y2 < 224) y2 += 2;
        if (p2 & Pad.left  != 0 and x2 > 8)   x2 -= 2;
        if (p2 & Pad.right != 0 and x2 < 248) x2 += 2;

        neslib.oam_clear();
        neslib.oam_spr(x1, y1, '1', 0x00);
        neslib.oam_spr(x2, y2, '2', 0x01);

        const bg_color: u8 = if (overlaps(x1, x2) and overlaps(y1, y2)) 0x16 else 0x0f;
        neslib.pal_col(0, bg_color);
    }
}
