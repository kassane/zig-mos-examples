// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! NES MMC3 mapper demo: banked_call, FamiTone2 music, mid-screen IRQ splits, WRAM.
//! Zig port of nesdoug 33_MMC3 / hello_mmc3.c by Doug Fraker.
//!
//! PRG layout (PRG_MODE_0, CHR_A12_INVERT):
//!   $8000–$9FFF  switchable (set_prg_8000)
//!   $A000–$BFFF  switchable (reset stub fixes to bank 61 — do not touch)
//!   $C000–$DFFF  fixed second-to-last bank
//!   $E000–$FFFF  fixed last bank (reset / NMI vectors)
//!
//! CHR layout (CHR_A12_INVERT, 2×2KB + 4×1KB banks):
//!   Regs 0/1 → 2KB CHR banks (sprites, $1000–$1FFF)
//!   Regs 2–5 → 1KB CHR banks (background, $0000–$0FFF)
//!
//! Run with: mos-sim / mednafen / Mesen2

pub const panic = @import("mos_panic");
const neslib = @import("neslib");
const nesdoug = @import("nesdoug");
const mapper = @import("mapper");

// Declare 8 KiB WRAM in the iNES header.
comptime {
    asm (
        \\.globl __prg_ram_size
        \\__prg_ram_size=8
    );
}

// ── Metasprite data ───────────────────────────────────────────────────────────
// 16×16 px sprites: 4 tiles + sentinel byte 128.
const round_spr_l: [17]u8 = .{
    0xff, 0xff, 0x02, 0,
    7,    0xff, 0x03, 0,
    0xff, 7,    0x12, 0,
    7,    7,    0x13, 0,
    128,
};
const round_spr_r: [17]u8 = .{
    0xff, 0xff, 0x00, 0,
    7,    0xff, 0x01, 0,
    0xff, 7,    0x10, 0,
    7,    7,    0x11, 0,
    128,
};

// ── Global state ──────────────────────────────────────────────────────────────
var arg1: u8 = 0;
var arg2: u8 = 0;
var sprite_x: u8 = 0;
var sprite_y: u8 = 0;
var dir_lr: u8 = 0;
var irq_array: [32]u8 = undefined;
var double_buffer: [32]u8 = undefined;

// WRAM mapped at $6000–$7FFF (8 KiB); not zero-init'd by reset code.
var wram_array: [0x2000]u8 linksection(".prg_ram") = undefined;

// ── Symbols from music.s (bank 12) ───────────────────────────────────────────
extern const music_data: u8;
extern const sounds_data: u8;

// ── set_irq_ptr override ──────────────────────────────────────────────────────
// irq.c defines set_irq_ptr as __attribute__((weak)).  The SDK's compiled
// version spills the argument onto a soft stack (rc0:rc1) before writing to
// __irq_ptr.  clearRAM zeroes all ZP (including rc0:rc1) before main() runs,
// so by the time set_irq_ptr is called, rc0:rc1 often points into ROM — the
// spill write is silently discarded and __irq_ptr receives ROM bytes instead
// of the actual address.  This strong definition bypasses the soft stack by
// assigning directly; the compiler emits a plain ZP store pair.
extern var __irq_ptr: ?*const anyopaque;
pub export fn set_irq_ptr(address: ?*const anyopaque) callconv(.c) void {
    __irq_ptr = address;
}

// ── Banked functions ──────────────────────────────────────────────────────────
// Each function is placed in its own PRG ROM bank section so banked_call()
// can switch the $8000–$9FFF window to that bank before executing.

noinline fn functionBank0() linksection(".prg_rom_0.text") callconv(.c) void {
    neslib.ppu_off();
    neslib.vram_adr(neslib.NTADR_A(1, 4));
    const text = "BANK0";
    neslib.vram_write(text, text.len);
    neslib.ppu_on_all();
}

noinline fn functionBank1() linksection(".prg_rom_1.text") callconv(.c) void {
    neslib.ppu_off();
    neslib.vram_adr(neslib.NTADR_A(1, 6));
    const text = "BANK1";
    neslib.vram_write(text, text.len);
    neslib.ppu_on_all();
    // Cross-bank call: bank 1 → bank 2 (nested banked_call is safe in MMC3).
    mapper.banked_call(2, &functionBank2);
}

// Helper in the same bank as functionBank2; called directly (no banked_call).
noinline fn functionSameBank() linksection(".prg_rom_2.text") callconv(.c) void {
    neslib.vram_put(0);
    neslib.vram_put('H');
    neslib.vram_put('I');
}

noinline fn functionBank2() linksection(".prg_rom_2.text") callconv(.c) void {
    neslib.ppu_off();
    neslib.vram_adr(neslib.NTADR_A(1, 8));
    const text = "BANK2";
    neslib.vram_write(text, text.len);
    functionSameBank(); // same bank → regular call
    neslib.ppu_on_all();
}

noinline fn functionBank3() linksection(".prg_rom_3.text") callconv(.c) void {
    neslib.ppu_off();
    neslib.vram_adr(neslib.NTADR_A(1, 10));
    const text = "BANK3";
    neslib.vram_write(text, text.len);
    neslib.vram_put(0);
    neslib.vram_put(arg1); // passed via globals (6502 has no stack args)
    neslib.vram_put(arg2);
    neslib.ppu_on_all();
}

noinline fn functionBank6() linksection(".prg_rom_6.text") callconv(.c) void {
    neslib.ppu_off();
    neslib.vram_adr(neslib.NTADR_A(1, 14));
    const text = "BANK6";
    neslib.vram_write(text, text.len);
    neslib.vram_put(0);
    neslib.vram_put(wram_array[0]); // should print 'A'
    neslib.vram_put(wram_array[2]); // should print 'C'
    neslib.ppu_on_all();
}

// ── Fixed-bank helpers ────────────────────────────────────────────────────────

fn drawSprites() void {
    neslib.oam_clear();
    if (dir_lr == 0) {
        neslib.oam_meta_spr(sprite_x, sprite_y, &round_spr_l);
    } else {
        neslib.oam_meta_spr(sprite_x, sprite_y, &round_spr_r);
    }
}

// ── main ──────────────────────────────────────────────────────────────────────

pub export fn main() callconv(.c) void {
    // clearRAM (init chain) zeros all ZP including rc0:rc1 (LLVM-MOS soft stack
    // pointer).  __do_init_stack runs immediately before clearRAM and sets
    // rc0:rc1=$0800, but clearRAM overwrites it.  Reinitialize here so compiled
    // C library functions that spill through the soft stack (e.g. vram_adr)
    // write to valid RAM ($07FE-$07FF) instead of ROM ($FFFE-$FFFF).
    asm volatile (
        \\lda #0
        \\sta $0
        \\lda #8
        \\sta $1
    );
    mapper.disable_irq();
    asm volatile ("cli"); // enable CPU interrupts

    // Configure MMC3 registers before any rendering.
    mapper.set_prg_mode(mapper.PRG_MODE_0);
    mapper.set_chr_a12_inversion(mapper.CHR_A12_INVERT);
    mapper.set_prg_8000(0);
    // CHR_A12_INVERT: regs 0/1 → sprites ($1000); regs 2–5 → BG ($0000).
    mapper.set_chr_bank(0, 4); // sprites: tiles 0x80–0xFF (Alpha.chr upper half)
    mapper.set_chr_bank(1, 6); // sprites: tiles 0x00–0x7F (Gears.chr upper half)
    mapper.set_chr_bank(2, 0); // BG 1KB bank 0
    mapper.set_chr_bank(3, 1); // BG 1KB bank 1
    mapper.set_chr_bank(4, 2); // BG 1KB bank 2
    mapper.set_chr_bank(5, 3); // BG 1KB bank 3
    mapper.set_wram_mode(mapper.WRAM_ON);

    neslib.banked_music_init(12, &music_data);
    neslib.banked_sounds_init(12, &sounds_data);

    mapper.set_mirroring(mapper.MIRROR_HORIZONTAL);
    neslib.bank_spr(1); // sprites use second pattern table ($1000)

    // IRQ array: 0xFF = end-of-data sentinel; overwritten each frame.
    irq_array[0] = 0xff;
    mapper.set_irq_ptr(&irq_array);

    // Clear WRAM ($6000–$7FFF); reset code does NOT zero this region.
    @memset(&wram_array, 0);
    wram_array[0] = 'A';
    wram_array[2] = 'C';

    neslib.ppu_off();

    const palette_bg: [16]u8 = .{
        0x0f, 0x00, 0x10, 0x30,
        0x0f, 0x00, 0x00, 0x00,
        0x0f, 0x00, 0x00, 0x00,
        0x0f, 0x00, 0x00, 0x00,
    };
    neslib.pal_bg(&palette_bg);

    const palette_spr: [16]u8 = .{
        0x0f, 0x09, 0x19, 0x29, // greens
        0x0f, 0x00, 0x00, 0x00,
        0x0f, 0x00, 0x00, 0x00,
        0x0f, 0x00, 0x00, 0x00,
    };
    neslib.pal_spr(&palette_spr);

    // Draw gear + square tiles in two groups.
    neslib.vram_adr(neslib.NTADR_A(20, 3));
    neslib.vram_put(0xc0);
    neslib.vram_put(0xc1);
    neslib.vram_put(0xc2);
    neslib.vram_put(0xc3);
    neslib.vram_adr(neslib.NTADR_A(20, 4));
    neslib.vram_put(0xd0);
    neslib.vram_put(0xd1);
    neslib.vram_put(0xd2);
    neslib.vram_put(0xd3);
    neslib.vram_adr(neslib.NTADR_A(20, 7));
    neslib.vram_put(0xc0);
    neslib.vram_put(0xc1);
    neslib.vram_put(0xc2);
    neslib.vram_put(0xc3);
    neslib.vram_adr(neslib.NTADR_A(20, 8));
    neslib.vram_put(0xd0);
    neslib.vram_put(0xd1);
    neslib.vram_put(0xd2);
    neslib.vram_put(0xd3);

    // Solid color blocks.
    neslib.vram_adr(neslib.NTADR_A(20, 5));
    for (0..4) |_| neslib.vram_put(0x02);
    neslib.vram_adr(neslib.NTADR_A(20, 9));
    for (0..4) |_| neslib.vram_put(0x02);
    neslib.vram_adr(neslib.NTADR_A(20, 13));
    for (0..4) |_| neslib.vram_put(0x02);

    neslib.music_play(0);
    mapper.set_chr_mode_5(8); // load gear tiles before first frame

    // Exercise banked_call across banks 0–3 and 6.
    mapper.banked_call(0, &functionBank0);
    mapper.banked_call(1, &functionBank1); // bank 1 internally calls bank 2
    arg1 = 'G';
    arg2 = '4';
    mapper.banked_call(3, &functionBank3);
    mapper.banked_call(6, &functionBank6);

    // Back in the fixed bank — draw a label.
    neslib.ppu_off();
    neslib.vram_adr(neslib.NTADR_A(1, 16));
    const text_fixed = "BACK IN FIXED BANK";
    neslib.vram_write(text_fixed, text_fixed.len);

    sprite_x = 0x50;
    sprite_y = 0x30;
    drawSprites();

    neslib.ppu_on_all();

    // Scrolling state (8.8 fixed-point; high byte = pixel scroll).
    var scroll_top: u16 = 0;
    var scroll2: u16 = 0;
    var scroll3: u16 = 0;
    var scroll4: u16 = 0;
    var char_state: u8 = 0;

    while (true) {
        neslib.ppu_wait_nmi();

        const pad1 = neslib.pad_poll(0);
        _ = nesdoug.get_pad_new(0);

        // A/B shift horizontal scroll at different speeds per split zone.
        if (pad1 & 0x80 != 0) { // PAD_A — scroll all zones left
            scroll_top -%= 0x0080;
            scroll2 -%= 0x0100;
            scroll3 -%= 0x0180;
            scroll4 -%= 0x0200;
        }
        if (pad1 & 0x40 != 0) { // PAD_B — scroll all zones right
            scroll_top +%= 0x0080;
            scroll2 +%= 0x0100;
            scroll3 +%= 0x0180;
            scroll4 +%= 0x0200;
        }
        nesdoug.set_scroll_x(scroll_top >> 8);

        // Cycle CHR tile animation every 4 frames.
        if ((nesdoug.get_frame_count() & 0x03) == 0) {
            char_state +%= 1;
            if (char_state >= 4) char_state = 0;
        }

        // Build double-buffered IRQ command array.
        // Format bytes: value < 0xF0 → scanline count;  0xF1 → $2001 write;
        //               0xF5 → H-scroll;  0xF6 → double $2006 write;
        //               0xFC → CHR mode 5;  0xFF → end.

        // Pre-split (during vblank): set BG CHR bank.
        double_buffer[0] = 0xfc;
        double_buffer[1] = 8; // CHR bank for top zone
        double_buffer[2] = 47; // scanlines until split 1

        // Split 1: change H-scroll and animate CHR tile.
        double_buffer[3] = 0xf5;
        double_buffer[4] = @truncate(scroll2 >> 8);
        double_buffer[5] = 0xfc;
        double_buffer[6] = 8 + char_state;
        double_buffer[7] = 29; // scanlines until split 2

        // Split 2: change H-scroll and darken color emphasis.
        double_buffer[8] = 0xf5;
        double_buffer[9] = @truncate(scroll3 >> 8);
        double_buffer[10] = 0xf1; // write to $2001 (PPU_MASK)
        double_buffer[11] = 0xfe; // COL_EMP_DARK (0xe0) | 0x1e
        double_buffer[12] = 30; // scanlines until split 3

        // Split 3: change H-scroll.
        double_buffer[13] = 0xf5;
        double_buffer[14] = @truncate(scroll4 >> 8);
        double_buffer[15] = 30; // scanlines until split 4

        // Split 4: reset scroll to 0 via $2005/$2006.
        double_buffer[16] = 0xf5;
        double_buffer[17] = 0; // fine X = 0
        double_buffer[18] = 0xf6; // two writes to $2006
        double_buffer[19] = 0x20; // high byte of $2000
        double_buffer[20] = 0x00; // low byte of $2000

        double_buffer[21] = 0xff; // end of IRQ command list

        // D-pad: move sprite.
        if (pad1 & 0x02 != 0) { // PAD_LEFT
            sprite_x -%= 1;
            dir_lr = 0;
        } else if (pad1 & 0x01 != 0) { // PAD_RIGHT
            sprite_x +%= 1;
            dir_lr = 1;
        }
        if (pad1 & 0x08 != 0) sprite_y -%= 1; // PAD_UP
        if (pad1 & 0x04 != 0) sprite_y +%= 1; // PAD_DOWN

        drawSprites();

        // Wait for IRQ handler to consume current irq_array before swapping.
        while (mapper.is_irq_done() == 0) {}
        @memcpy(&irq_array, &double_buffer);
    }
}
