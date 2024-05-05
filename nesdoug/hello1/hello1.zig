const neslib = @import("neslib");

export fn main() callconv(.C) void {
    const text = "Hello Zig!";
    const palette: [15]u8 = .{
        0x0f,
        0x00,
        0x10,
        0x30,
    } ++ [1]u8{0} ** 11;

    neslib.ppu_off();
    neslib.pal_bg(@as(
        ?*const anyopaque,
        @ptrCast(@as(
            [*c]const u8,
            @ptrCast(@alignCast(&palette)),
        )),
    ));
    neslib.vram_adr(neslib.NTADR_A(10, 14));
    for (text[0.. :0]) |c| {
        neslib.vram_put(c);
    }
    neslib.ppu_on_all();
    while (true) {}
}
