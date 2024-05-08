const neslib = @import("neslib.zig");

pub export fn main() callconv(.C) void {
    const palette: [15]u8 = .{
        0x0f,
        0x00,
        0x10,
        0x30,
    } ++ [1]u8{0} ** 11;

    // example of sequential vram data
    const text = &[16]u8{
        // where to write, repeat horizontally
        neslib.MSB(neslib.NTADR_A(10, 14)) | neslib.NT_UPD_HORZ,
        neslib.LSB(neslib.NTADR_A(10, 14)),
        12, // length of write
        'H', // the data to be written, 12 chars
        'E',
        'L',
        'L',
        'O',
        ' ',
        'W',
        'O',
        'R',
        'L',
        'D',
        '!',
        neslib.NT_UPD_EOF, // data must end in EOF
    };

    // example of non-sequential vram data
    const two_letters = &[7]u8{
        neslib.MSB(neslib.NTADR_A(8, 17)),
        neslib.LSB(neslib.NTADR_A(8, 17)),
        'A',
        neslib.MSB(neslib.NTADR_A(18, 5)),
        neslib.LSB(neslib.NTADR_A(18, 5)),
        'B',
        neslib.NT_UPD_EOF, // data must end in EOF
    };

    neslib.ppu_off(); // screen off

    neslib.pal_bg(&palette); //	load the palette

    neslib.ppu_on_all(); // turn on screen

    neslib.set_vram_update(text); // set a pointer to the data to transfer during nmi

    neslib.ppu_wait_nmi(); // waits until the next nmi is completed, also sets a VRAM
    // update flag the text will be auto pushed to the PPU during
    // nmi

    neslib.set_vram_update(two_letters); // set a pointer to the data

    neslib.ppu_wait_nmi(); // the two_letters will be auto pushed to the PPU in the next
    // nmi

    neslib.set_vram_update(null); // just turns off the VRAM update system so that it
    // isn't wasting time writing the same data to the PPU every frame

    while (true) {
        // infinite loop
        // game code can go here later.
    }
}
