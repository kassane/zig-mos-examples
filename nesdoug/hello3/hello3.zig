const neslib = @import("neslib.zig");
const nesdoug = @import("nesdoug.zig");

pub export fn main() callconv(.C) void {
    const palette: [15]u8 = .{
        0x0f,
        0x00,
        0x10,
        0x30,
    } ++ [1]u8{0} ** 11;

    // example of sequential vram data
    const text = &[12]u8{
        'H', 'E', 'L', 'L', 'O', ' ',
        'W', 'O', 'R', 'L', 'D', '!',
    };

    // example of single byte write
    const letter: u8 = 'A';

    neslib.ppu_on_all(); // turn on screen

    neslib.pal_bg(&palette); //	load the palette

    neslib.ppu_wait_nmi(); // wait

    // now fill the vram_buffer

    nesdoug.set_vram_buffer(); // points ppu update to vram_buffer, do this at least once

    nesdoug.one_vram_buffer(letter, neslib.NTADR_A(2, 3)); // pushes 1 byte worth of data to the vram_buffer
    nesdoug.one_vram_buffer(0x42, neslib.NTADR_A(5, 6)); // another 1 byte write, letter B

    // optionally, you could use this function to get the ppu address at run time
    const address = nesdoug.get_ppu_addr(0, 0x38, 0xc0); // (char nt, char x, char y);
    nesdoug.one_vram_buffer('C', address); // another 1 byte write

    nesdoug.multi_vram_buffer_horz(text, text.len, neslib.NTADR_A(10, 7)); // pushes 12 bytes, horz
    nesdoug.multi_vram_buffer_horz(text, text.len, neslib.NTADR_A(12, 12)); // lower
    nesdoug.multi_vram_buffer_horz(text, text.len, neslib.NTADR_A(14, 17)); // lower still

    nesdoug.multi_vram_buffer_vert(text, text.len, neslib.NTADR_A(10, 7)); // vertical

    // we've done 51 bytes of transfer to the ppu in 1 v-blank

    // do not try to push much more than 30 non-sequential or 70 sequential bytes
    // at once

    neslib.ppu_wait_nmi(); // wait

    while (true) {
        // infinite loop
        // game code can go here later.
    }
}
