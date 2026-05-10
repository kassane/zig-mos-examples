// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! MEGA65 Mandelbrot FCM: Full Color Mode 320×200 escape-time fractal.
//! Per-pixel palette via VIC-IV CHR16+FCLRHI; 32×32 hardware math; Enhanced DMA; 40 MHz.
pub const panic = @import("mos_panic");
const mega65 = @import("mega65");

// ── Fixed-point type (8.8: high byte = integer, low byte = fraction) ──────────
const Fix16 = i16;
const FP_ONE: Fix16 = 256;

// ── Fractal and screen geometry ───────────────────────────────────────────────
const MAX_ITER: u8 = 32;
const CELL_COLS: u8 = 40;
const CELL_ROWS: u8 = 25;
const TILE_PIXELS: u8 = 8;
const TILE_BYTES: u16 = @as(u16, TILE_PIXELS) * TILE_PIXELS; // 64
const TILE_ROW_BYTES: u16 = @as(u16, CELL_COLS) * TILE_BYTES; // 2560
const NUM_CELLS: u16 = @as(u16, CELL_COLS) * CELL_ROWS; // 1000

// FCM tile base: charptr=0, so tile N → address N×64.  $40000/64 = 4096 = 0x1000.
const GFX_ADDR: u32 = 0x40000;
const TILE_BASE: u16 = 0x1000;

// ── VIC-IV register file at $D000 ─────────────────────────────────────────────
const vic: *volatile mega65.__vic4 = @ptrFromInt(0xd000);

// ── VIC mask constants (from _vic4.h / _vic3.h) ───────────────────────────────
const VIC3_FAST_MASK: u8 = 0x40;
const VIC3_ATTR_MASK: u8 = 0x20;
const VIC3_H640_MASK: u8 = 0x80;
const VIC3_V400_MASK: u8 = 0x08;
const VIC3_PAL_MASK: u8 = 0x04;
const VIC4_CHR16_MASK: u8 = 0x01;
const VIC4_FCLRLO_MASK: u8 = 0x02;
const VIC4_FCLRHI_MASK: u8 = 0x04;
const VIC4_HOTREG_MASK: u8 = 0x80;

// ── Hardware math accelerator at $D768 ───────────────────────────────────────
// Combinational 32×32→64-bit multiplier; result updates as soon as both inputs written.
const math_a: *volatile i32 = @ptrFromInt(0xd768); // multina32
const math_b: *volatile i32 = @ptrFromInt(0xd76c); // multinb32
const math_out: *volatile i32 = @ptrFromInt(0xd770); // multout32 (lower 32 of 64-bit)

// ── Palette RAM at $D100 ──────────────────────────────────────────────────────
const pal_red: [*]volatile u8 = @ptrFromInt(0xd100);
const pal_green: [*]volatile u8 = @ptrFromInt(0xd200);
const pal_blue: [*]volatile u8 = @ptrFromInt(0xd300);

// ── Screen and color RAM ──────────────────────────────────────────────────────
const screen16: [*]volatile u16 = @ptrFromInt(0x0800);
const color_ram: [*]volatile u8 = @ptrFromInt(0xd800);

// ── CPU port DDR at $0000 (write 65 for 40 MHz full-speed mode) ───────────────
const cpu_portddr: *allowzero volatile u8 = @ptrFromInt(0x0000);

// ── VIC-IV sub-registers (inside anonymous union sub-structs; accessed directly) ─
const scrnptr_lsb: *volatile u8 = @ptrFromInt(0xd060);
const scrnptr_msb: *volatile u8 = @ptrFromInt(0xd061);
const scrnptr_bnk: *volatile u8 = @ptrFromInt(0xd062);
const scrnptr_mb: *volatile u8 = @ptrFromInt(0xd063);
const charptr_lsb: *volatile u8 = @ptrFromInt(0xd068);
const charptr_msb: *volatile u8 = @ptrFromInt(0xd069);
const charptr_bnk: *volatile u8 = @ptrFromInt(0xd06a);

// ── DMA option byte constants ─────────────────────────────────────────────────
const ENABLE_F018B_OPT: u8 = 0x0b;
const SRC_ADDR_BITS_OPT: u8 = 0x80;
const DST_ADDR_BITS_OPT: u8 = 0x81;
const DST_SKIP_RATE_OPT: u8 = 0x85;
const DMA_COPY_CMD: u8 = 0x00;
const DMA_FILL_CMD: u8 = 0x03;

// ── F018B DMA list (12 bytes, packed = no padding between fields) ─────────────
const DMAList_F018B = packed struct {
    command: u8,
    count: u16,
    source_addr: u16,
    source_bank: u8,
    dest_addr: u16,
    dest_bank: u8,
    command_msb: u8,
    modulo: u16,
};

// ── Enhanced DMA job: 7 option bytes + end byte + F018B list ─────────────────
const DmaJob = packed struct {
    opt0: u8,
    opt1: u8,
    opt2: u8,
    opt3: u8,
    opt4: u8,
    opt5: u8,
    opt6: u8,
    end_option: u8,
    dmalist: DMAList_F018B,
};

// ── Tile row buffer: CPU-side staging area, one row at a time (BSS) ───────────
var tile_row_buf: [TILE_ROW_BYTES]u8 = undefined;

// ── Comptime palette: blue→cyan→green→yellow→red over MAX_ITER steps ──────────
// Entry 0 = black (interior / set member). Entries 1..MAX_ITER = escaped pixels.
// Reversed-nybble encoding: 4-bit intensity n → (n<<4)|n for full brightness.
const SEGMENT_LEN: u8 = 8;
const MAX_INTENSITY: u8 = 15;

fn nyb(n: u8) u8 {
    return (n << 4) | n;
}

const Palette = struct { r: [MAX_ITER + 1]u8, g: [MAX_ITER + 1]u8, b: [MAX_ITER + 1]u8 };

const palette: Palette = blk: {
    var p = Palette{
        .r = @splat(0),
        .g = @splat(0),
        .b = @splat(0),
    };
    var i: u8 = 0;
    while (i < MAX_ITER) : (i += 1) {
        const pos: u8 = i & (SEGMENT_LEN - 1);
        const v: u8 = @intCast(@as(u16, pos) * MAX_INTENSITY / (SEGMENT_LEN - 1));
        var rv: u8 = 0;
        var gv: u8 = 0;
        var bv: u8 = 0;
        if (i < SEGMENT_LEN) {
            gv = v;
            bv = MAX_INTENSITY;
        } else if (i < SEGMENT_LEN * 2) {
            gv = MAX_INTENSITY;
            bv = MAX_INTENSITY - v;
        } else if (i < SEGMENT_LEN * 3) {
            rv = v;
            gv = MAX_INTENSITY;
        } else {
            rv = MAX_INTENSITY;
            gv = MAX_INTENSITY - v;
        }
        p.r[i + 1] = nyb(rv);
        p.g[i + 1] = nyb(gv);
        p.b[i + 1] = nyb(bv);
    }
    break :blk p;
};

// ── Hardware 8.8 fixed-point multiply ────────────────────────────────────────
// Sign-extend 16-bit inputs to 32 bits; lower 32 bits of unsigned product
// match the signed result for equal-width inputs. Shift right 8 → 8.8 result.
inline fn fpMul(a: Fix16, b: Fix16) Fix16 {
    math_a.* = @as(i32, a);
    math_b.* = @as(i32, b);
    return @truncate(math_out.* >> 8);
}

// ── Escape-time Mandelbrot iteration ─────────────────────────────────────────
fn mandelbrot(cr: Fix16, ci: Fix16) u8 {
    const FP_FOUR: Fix16 = 4 * FP_ONE;
    var zr: Fix16 = 0;
    var zi: Fix16 = 0;
    var i: u8 = 0;
    while (i < MAX_ITER) : (i += 1) {
        const zr2 = fpMul(zr, zr);
        const zi2 = fpMul(zi, zi);
        if (zr2 + zi2 > FP_FOUR) return i;
        zi = fpMul(zr, zi);
        zi +%= zi; // 2·zr·zi (wrapping matches C int16_t)
        zi +%= ci;
        zr = zr2 - zi2 + cr;
    }
    return MAX_ITER;
}

// ── Enhanced DMA helpers ──────────────────────────────────────────────────────
fn triggerDma(job: *const DmaJob) void {
    // addr_msb must be written before trigger_enhanced (the write that starts DMA).
    const addr: u16 = @intCast(@intFromPtr(job));
    const dma_enable: *volatile u8 = @ptrFromInt(0xd703); // enable_f018b
    const dma_bank: *volatile u8 = @ptrFromInt(0xd702); // addr_bank
    const dma_msb: *volatile u8 = @ptrFromInt(0xd701); // addr_msb
    const dma_trigger: *volatile u8 = @ptrFromInt(0xd705); // trigger_enhanced
    dma_enable.* = 1;
    dma_bank.* = 0;
    dma_msb.* = @truncate(addr >> 8);
    dma_trigger.* = @truncate(addr); // triggers DMA
}

fn makeDmaFill(dst: u32, value: u8, count: u16) DmaJob {
    return .{
        .opt0 = ENABLE_F018B_OPT,
        .opt1 = SRC_ADDR_BITS_OPT,
        .opt2 = 0,
        .opt3 = DST_ADDR_BITS_OPT,
        .opt4 = @truncate(dst >> 20),
        .opt5 = DST_SKIP_RATE_OPT,
        .opt6 = 1,
        .end_option = 0,
        .dmalist = .{
            .command = DMA_FILL_CMD,
            .count = count,
            .source_addr = value,
            .source_bank = 0,
            .dest_addr = @truncate(dst),
            .dest_bank = @truncate(dst >> 16),
            .command_msb = 0,
            .modulo = 0,
        },
    };
}

fn makeDmaCopy(src: u32, dst: u32, count: u16) DmaJob {
    var job = makeDmaFill(dst, 0, count);
    job.opt2 = @truncate(src >> 20);
    job.dmalist.command = DMA_COPY_CMD;
    job.dmalist.source_addr = @truncate(src);
    job.dmalist.source_bank = @truncate(src >> 16);
    return job;
}

// ── VIC-IV setup: FCM 320×200 mode ───────────────────────────────────────────
fn setupVic() void {
    asm volatile ("sei");

    vic.key = 0x47; // VIC-IV unlock knock sequence
    vic.key = 0x53;

    // Disable hot registers so we can program VIC-IV directly
    (@as(*volatile u8, @ptrFromInt(0xd05d))).* &= ~VIC4_HOTREG_MASK;

    // 40 MHz: POKE 0,65 via CPU port DDR (VIC3_FAST alone gives only 3.5 MHz)
    cpu_portddr.* = 65;

    vic.ctrlb = (vic.ctrlb | VIC3_FAST_MASK | VIC3_ATTR_MASK) &
        ~(VIC3_H640_MASK | VIC3_V400_MASK);

    // CHR16 + FCLRHI: tiles with index > $FF use full-color per-pixel palette.
    // Our indices start at 0x1000, so every tile uses FCM.
    vic.ctrlc = (vic.ctrlc & ~VIC4_FCLRLO_MASK) | VIC4_CHR16_MASK | VIC4_FCLRHI_MASK;

    // Screen RAM at $0800 (reuse KERNAL default — avoids relocating 2 KB)
    scrnptr_lsb.* = 0x00;
    scrnptr_msb.* = 0x08;
    scrnptr_bnk.* = 0x00;
    scrnptr_mb.* = 0x00;

    // Tile data base at address 0; tile N maps to bytes [N×64 .. N×64+63]
    charptr_lsb.* = 0x00;
    charptr_msb.* = 0x00;
    charptr_bnk.* = 0x00;

    // 80 bytes per row (CHR16: 2 bytes/cell × 40 cols), 40 chars, 25 rows
    vic.linestep = @as(u16, CELL_COLS) * 2;
    vic.chrcount = CELL_COLS;
    vic.disp_rows = CELL_ROWS;

    // FCM is a text-mode extension — BMM must be off.
    // Preserve raster MSB ($C0), set DEN|RSEL|YSCROLL=3 ($1B).
    vic.ctrl1 = (vic.ctrl1 & 0xC0) | 0x1B;
    // Preserve unused high bits ($E0), set CSEL ($08).
    vic.ctrl2 = (vic.ctrl2 & 0xE0) | 0x08;

    vic.bordercol = 0;
    vic.screencol = 0;

    // Use palette RAM for colors 0-15 (16+ always use palette RAM)
    vic.ctrla |= VIC3_PAL_MASK;
}

// ── Screen and tile memory initialization ─────────────────────────────────────
fn setupScreen() void {
    // Upload the comptime palette into hardware palette RAM
    for (0..MAX_ITER + 1) |i| {
        pal_red[i] = palette.r[i];
        pal_green[i] = palette.g[i];
        pal_blue[i] = palette.b[i];
    }

    // Each screen cell gets a unique tile index pointing into $40000 graphics area
    for (0..NUM_CELLS) |i| {
        screen16[i] = TILE_BASE + @as(u16, @intCast(i));
    }

    // Neutral color RAM: prevent unwanted FCM flip/alpha attributes
    for (0..NUM_CELLS) |i| {
        color_ram[i] = 0;
    }

    // Zero the whole graphics area so unrendered rows appear black
    const fill_job = makeDmaFill(GFX_ADDR, 0, NUM_CELLS * TILE_BYTES);
    triggerDma(&fill_job);
}

// ── Fractal rendering: one tile row at a time, DMA-copied to $40000+ ──────────
fn renderFractal() void {
    // View window: real ∈ [−2.0, 0.6], imag ∈ [−1.0, 1.0]
    const RE_MIN: Fix16 = -2 * FP_ONE;
    const RE_MAX: Fix16 = @intFromFloat(0.6 * 256.0);
    const IM_MIN: Fix16 = -FP_ONE;
    const IM_MAX: Fix16 = FP_ONE;
    const RE_STEP: Fix16 = (RE_MAX - RE_MIN) / 320;
    const IM_STEP: Fix16 = (IM_MAX - IM_MIN) / 200;

    for (0..CELL_ROWS) |cy| {
        for (0..CELL_COLS) |cx| {
            const tile_off: u16 = @as(u16, @intCast(cx)) * TILE_BYTES;
            for (0..TILE_PIXELS) |py| {
                const y: Fix16 = @intCast(@as(u16, @intCast(cy)) * TILE_PIXELS + py);
                for (0..TILE_PIXELS) |px| {
                    const x: Fix16 = @intCast(@as(u16, @intCast(cx)) * TILE_PIXELS + px);
                    const cr: Fix16 = RE_MIN + x * RE_STEP;
                    const ci: Fix16 = IM_MIN + y * IM_STEP;
                    const iter = mandelbrot(cr, ci);
                    tile_row_buf[tile_off + py * TILE_PIXELS + px] =
                        if (iter >= MAX_ITER) 0 else iter + 1;
                }
            }
        }

        // DMA-copy completed tile row from CPU RAM to graphics memory
        const src: u32 = @intFromPtr(&tile_row_buf);
        const dst: u32 = GFX_ADDR + @as(u32, @intCast(cy)) * TILE_ROW_BYTES;
        const copy_job = makeDmaCopy(src, dst, TILE_ROW_BYTES);
        triggerDma(&copy_job);
    }
}

export fn main() void {
    setupVic();
    setupScreen();
    renderFractal();
    while (true) {}
}
