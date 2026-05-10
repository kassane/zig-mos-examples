// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! MEGA65 vector logo: rotating wireframe "LLVM-MOS" on a 320×200 hires bitmap.
//! VIC-II BMM mode; hardware 32×32 math for fixed-point rotation; Enhanced DMA clear;
pub const panic = @import("mos_panic");
const std = @import("std");
const mega65 = @import("mega65");

// ── Fixed-point type (8.8) ────────────────────────────────────────────────────
const Fix16 = i16;
const FP_ONE: Fix16 = 256;

// ── Screen geometry ───────────────────────────────────────────────────────────
const SCREEN_W: u16 = 320;
const SCREEN_H: u16 = 200;
const CELL_COLS: u8 = 40;
const CELL_ROWS: u8 = 25;
const SCREEN_RAM_SIZE: u16 = @as(u16, CELL_COLS) * CELL_ROWS; // 1000 color nybble cells
const CELL_ROW_BYTES: u16 = @as(u16, CELL_COLS) * 8; // 320 bytes per 8-pixel-tall cell row
const BITMAP_SIZE: u16 = CELL_ROW_BYTES * CELL_ROWS; // 8000 bytes

// BMM rounds charptr to 8 KB boundary → bitmap must be 8 KB-aligned.
const BITMAP_ALIGN: u16 = 8192;

// ── VIC-IV register file at $D000 ─────────────────────────────────────────────
const vic: *volatile mega65.__vic4 = @ptrFromInt(0xd000);

// ── VIC mask constants ────────────────────────────────────────────────────────
const VIC3_FAST_MASK: u8 = 0x40;
const VIC3_H640_MASK: u8 = 0x80;
const VIC3_V400_MASK: u8 = 0x08;
const VIC4_CHR16_MASK: u8 = 0x01;
const VIC4_FCLRLO_MASK: u8 = 0x02;
const VIC4_FCLRHI_MASK: u8 = 0x04;
const VIC4_HOTREG_MASK: u8 = 0x80;

// ── Hardware math accelerator at $D768 ───────────────────────────────────────
const math_a: *volatile i32 = @ptrFromInt(0xd768);
const math_b: *volatile i32 = @ptrFromInt(0xd76c);
const math_out: *volatile i32 = @ptrFromInt(0xd770);

// ── CPU port DDR at $0000 ─────────────────────────────────────────────────────
const cpu_portddr: *allowzero volatile u8 = @ptrFromInt(0x0000);

// ── VIC-IV sub-registers (inside anonymous union sub-structs; accessed directly) ─
const scrnptr_lsb: *volatile u8 = @ptrFromInt(0xd060);
const scrnptr_msb: *volatile u8 = @ptrFromInt(0xd061);
const scrnptr_bnk: *volatile u8 = @ptrFromInt(0xd062);
const scrnptr_mb: *volatile u8 = @ptrFromInt(0xd063);
const charptr_lsb: *volatile u8 = @ptrFromInt(0xd068);
const charptr_msb: *volatile u8 = @ptrFromInt(0xd069);
const charptr_bnk: *volatile u8 = @ptrFromInt(0xd06a);

// ── DMA constants ─────────────────────────────────────────────────────────────
const ENABLE_F018B_OPT: u8 = 0x0b;
const SRC_ADDR_BITS_OPT: u8 = 0x80;
const DST_ADDR_BITS_OPT: u8 = 0x81;
const DST_SKIP_RATE_OPT: u8 = 0x85;
const DMA_FILL_CMD: u8 = 0x03;

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

fn triggerDma(job: *const DmaJob) void {
    const addr: u16 = @intCast(@intFromPtr(job));
    const dma_enable: *volatile u8 = @ptrFromInt(0xd703);
    const dma_bank: *volatile u8 = @ptrFromInt(0xd702);
    const dma_msb: *volatile u8 = @ptrFromInt(0xd701);
    const dma_trigger: *volatile u8 = @ptrFromInt(0xd705);
    dma_enable.* = 1;
    dma_bank.* = 0;
    dma_msb.* = @truncate(addr >> 8);
    dma_trigger.* = @truncate(addr);
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

// ── Comptime sine table: 256 entries, 8.8 fixed-point, one full period ────────
// Uses std.math.sin — no Taylor series needed at comptime.
const sin_table: [256]Fix16 = blk: {
    @setEvalBranchQuota(100_000);
    var tbl: [256]Fix16 = undefined;
    for (0..256) |i| {
        const angle: f64 = @as(f64, @floatFromInt(i)) * (std.math.pi * 2.0 / 256.0);
        const s: f64 = @sin(angle) * 256.0 + 0.5;
        var val: i32 = @intFromFloat(s);
        if (val > 256) val = 256;
        tbl[i] = @intCast(val);
    }
    break :blk tbl;
};

fn sin8(angle: u8) Fix16 {
    return sin_table[angle];
}
fn cos8(angle: u8) Fix16 {
    return sin_table[@as(u8, angle +% 64)];
}

// ── Logo geometry: "LLVM-MOS" wireframe, x ∈ [−57,57], y ∈ [−8,8] ───────────
const Vertex = struct { x: i8, y: i8 };
const Segment = struct { v0: u8, v1: u8 };

const vertices = [_]Vertex{
    // L
    .{ .x = -54, .y = -8 }, .{ .x = -54, .y = 8 },  .{ .x = -46, .y = 8 },
    // L
    .{ .x = -42, .y = -8 }, .{ .x = -42, .y = 8 },  .{ .x = -34, .y = 8 },
    // V
    .{ .x = -32, .y = -8 }, .{ .x = -28, .y = 8 },  .{ .x = -24, .y = -8 },
    // M
    .{ .x = -20, .y = 8 },  .{ .x = -20, .y = -8 }, .{ .x = -14, .y = 0 },
    .{ .x = -8, .y = -8 },  .{ .x = -8, .y = 8 },
    // -
      .{ .x = -4, .y = 0 },
    .{ .x = 4, .y = 0 },
    // M
       .{ .x = 6, .y = 8 },    .{ .x = 6, .y = -8 },
    .{ .x = 12, .y = 0 },   .{ .x = 18, .y = -8 },  .{ .x = 18, .y = 8 },
    // O
    .{ .x = 22, .y = -8 },  .{ .x = 32, .y = -8 },  .{ .x = 32, .y = 8 },
    .{ .x = 22, .y = 8 },
    // S
      .{ .x = 46, .y = -8 },  .{ .x = 36, .y = -8 },
    .{ .x = 36, .y = 0 },   .{ .x = 46, .y = 0 },   .{ .x = 46, .y = 8 },
    .{ .x = 36, .y = 8 },
};

const segments = [_]Segment{
    .{ .v0 = 0, .v1 = 1 }, .{ .v0 = 1, .v1 = 2 }, // L
    .{ .v0 = 3, .v1 = 4 }, .{ .v0 = 4, .v1 = 5 }, // L
    .{ .v0 = 6, .v1 = 7 }, .{ .v0 = 7, .v1 = 8 }, // V
    .{ .v0 = 9, .v1 = 10 }, .{ .v0 = 10, .v1 = 11 }, .{ .v0 = 11, .v1 = 12 }, .{ .v0 = 12, .v1 = 13 }, // M
    .{ .v0 = 14, .v1 = 15 }, // -
    .{ .v0 = 16, .v1 = 17 }, .{ .v0 = 17, .v1 = 18 }, .{ .v0 = 18, .v1 = 19 }, .{ .v0 = 19, .v1 = 20 }, // M
    .{ .v0 = 21, .v1 = 22 }, .{ .v0 = 22, .v1 = 23 }, .{ .v0 = 23, .v1 = 24 }, .{ .v0 = 24, .v1 = 21 }, // O
    .{ .v0 = 25, .v1 = 26 }, .{ .v0 = 26, .v1 = 27 }, .{ .v0 = 27, .v1 = 28 }, .{ .v0 = 28, .v1 = 29 }, .{ .v0 = 29, .v1 = 30 }, // S
};

const NUM_VERTS = vertices.len;

// ── Bitmap and screen RAM (BSS) ───────────────────────────────────────────────
var bitmap: [BITMAP_SIZE]u8 align(BITMAP_ALIGN) = @splat(0);
var screen_ram: [SCREEN_RAM_SIZE]u8 = @splat(0);

// ── Projected screen coordinates (updated each frame) ────────────────────────
var screen_x: [NUM_VERTS]i16 = undefined;
var screen_y: [NUM_VERTS]i16 = undefined;

// ── Comptime row offset table: byte offset within bitmap for each screen row ──
// VIC-II BMM layout: 8 consecutive bytes per 8×8 cell, left-to-right then top-to-bottom.
const row_table: [SCREEN_H]u16 = blk: {
    var tbl: [SCREEN_H]u16 = undefined;
    for (0..SCREEN_H) |y| {
        tbl[y] = @intCast((y >> 3) * CELL_ROW_BYTES + (y & 7));
    }
    break :blk tbl;
};

const bit_mask = [8]u8{ 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01 };

// ── Pixel plotting ────────────────────────────────────────────────────────────
// Uses @bitCast to reinterpret signed as unsigned — negative coords wrap to
// large values and are caught by the unsigned bounds check (same as C++ cast).
fn plotPixel(x: i16, y: i16) void {
    const ux: u16 = @bitCast(x);
    const uy: u16 = @bitCast(y);
    if (ux >= SCREEN_W or uy >= SCREEN_H) return;
    bitmap[row_table[uy] + (ux & ~@as(u16, 7))] |= bit_mask[ux & 7];
}

// ── Bresenham line drawing ────────────────────────────────────────────────────
fn drawLine(x0: i16, y0: i16, x1: i16, y1: i16) void {
    var ax = x0;
    var ay = y0;
    var dx: i16 = x1 - x0;
    var dy: i16 = y1 - y0;
    var sx: i16 = 1;
    var sy: i16 = 1;

    if (dx < 0) {
        dx = -dx;
        sx = -1;
    }
    if (dy < 0) {
        dy = -dy;
        sy = -1;
    }

    if (dx >= dy) {
        var err: i16 = dx >> 1;
        var i: i16 = 0;
        while (i <= dx) : (i += 1) {
            plotPixel(ax, ay);
            err -= dy;
            if (err < 0) {
                ay += sy;
                err += dx;
            }
            ax += sx;
        }
    } else {
        var err: i16 = dy >> 1;
        var i: i16 = 0;
        while (i <= dy) : (i += 1) {
            plotPixel(ax, ay);
            err -= dx;
            if (err < 0) {
                ax += sx;
                err += dy;
            }
            ay += sy;
        }
    }
}

// ── Hardware math helpers ─────────────────────────────────────────────────────
// Split set/read lets the vertex loop reuse whichever input register is unchanged.
fn fpSetA(v: Fix16) void {
    math_a.* = @as(i32, v);
}
fn fpSetB(v: Fix16) void {
    math_b.* = @as(i32, v);
}
fn fpResult() Fix16 {
    return @truncate(math_out.* >> 8);
}
fn fpMul(a: Fix16, b: Fix16) Fix16 {
    fpSetA(a);
    fpSetB(b);
    return fpResult();
}

// ── Rotate, scale, and project all vertices to screen coordinates ─────────────
// Multiply ordering minimizes 32-bit MMIO writes by reusing unchanged inputs.
fn transformVertices(spin: u8, tilt: u8, yaw: u8, scale: Fix16) void {
    const ss = sin8(spin);
    const cs = cos8(spin);
    const ct = cos8(tilt);
    const cy = cos8(yaw);

    for (vertices, 0..) |v, i| {
        const vx: Fix16 = @as(Fix16, v.x) * FP_ONE;
        const vy: Fix16 = @as(Fix16, v.y) * FP_ONE;

        // Tilt (X-axis): foreshorten Y by cos(tilt)
        fpSetA(vy);
        fpSetB(ct);
        const vy_t = fpResult();

        // Spin components of vy_t
        fpSetA(vy_t);
        fpSetB(cs);
        const vy_t_cs = fpResult();
        fpSetB(ss);
        const vy_t_ss = fpResult();

        // Yaw (Y-axis): foreshorten X by cos(yaw)
        fpSetA(vx);
        fpSetB(cy);
        const vx_y = fpResult();

        // Spin components of vx_y
        fpSetA(vx_y);
        fpSetB(ss);
        const vx_y_ss = fpResult();
        fpSetB(cs);
        const vx_y_cs = fpResult();

        // Combine spin rotation + scale → screen center
        const rx: Fix16 = vx_y_cs - vy_t_ss;
        const ry: Fix16 = vx_y_ss + vy_t_cs;

        fpSetA(rx);
        fpSetB(scale);
        screen_x[i] = (fpResult() >> 8) + (SCREEN_W / 2);

        fpSetA(ry); // B=scale still loaded
        screen_y[i] = (fpResult() >> 8) + (SCREEN_H / 2);
    }
}

fn drawSegments() void {
    for (segments) |seg| {
        drawLine(screen_x[seg.v0], screen_y[seg.v0], screen_x[seg.v1], screen_y[seg.v1]);
    }
}

fn clearBitmap() void {
    const dst: u32 = @intCast(@intFromPtr(&bitmap));
    const job = makeDmaFill(dst, 0, BITMAP_SIZE);
    triggerDma(&job);
}

// ── VBlank sync: wait for visible area then wait for VBlank leading edge ──────
fn waitVblank() void {
    while (vic.ctrl1 & 0x80 != 0) {} // wait while raster MSB set (VBlank/overscan)
    while (vic.ctrl1 & 0x80 == 0) {} // wait for VBlank (raster MSB goes high)
}

// ── VIC-IV setup: C64-compatible hires bitmap mode ───────────────────────────
fn setupVic() void {
    // Orange foreground (6), blue background (6): upper nybble fg, lower nybble bg
    const CELL_COLOR: u8 = 0x86;

    asm volatile ("sei");

    vic.key = 0x47;
    vic.key = 0x53;

    (@as(*volatile u8, @ptrFromInt(0xd05d))).* &= ~VIC4_HOTREG_MASK;

    // 3.5 MHz C65 speed: clear extended speed bit, keep VIC3_FAST
    cpu_portddr.* &= ~@as(u8, 1);
    vic.ctrlb = (vic.ctrlb | VIC3_FAST_MASK) & ~(VIC3_H640_MASK | VIC3_V400_MASK);

    // Point screen RAM to our BSS array via extended scrnptr registers
    const scrn: u16 = @intCast(@intFromPtr(&screen_ram));
    scrnptr_lsb.* = @truncate(scrn);
    scrnptr_msb.* = @truncate(scrn >> 8);
    scrnptr_bnk.* = 0x00;
    scrnptr_mb.* = 0x00;

    // Point character/bitmap data to our 8 KB-aligned bitmap array
    const bm: u16 = @intCast(@intFromPtr(&bitmap));
    charptr_lsb.* = @truncate(bm);
    charptr_msb.* = @truncate(bm >> 8);
    charptr_bnk.* = 0x00;

    // 40-column, 25-row geometry (320×200 in BMM: 1 byte = 8 horizontal pixels)
    vic.linestep = CELL_COLS;
    vic.chrcount = CELL_COLS;
    vic.disp_rows = CELL_ROWS;

    // BMM=1, DEN=1, RSEL=1, YSCROLL=3 (no multicolor, no ECM)
    vic.ctrl1 = 0x3B;
    // Hires: CSEL=1, XSCROLL=0
    vic.ctrl2 = 0x08;
    // No FCM features
    vic.ctrlc &= ~(VIC4_CHR16_MASK | VIC4_FCLRHI_MASK | VIC4_FCLRLO_MASK);

    vic.bordercol = 6; // blue
    vic.screencol = 6;

    // Set each cell's fg/bg color nybbles
    @memset(&screen_ram, CELL_COLOR);
}

export fn main() void {
    setupVic();

    // Base scale: ~2.1× in 8.8 fixed-point (fills ~75 % of screen width)
    const SCALE: Fix16 = 540;
    // Breathing amplitude: scale oscillates ±BREATH_AMP around SCALE
    const BREATH_AMP: Fix16 = 70;

    // 16.8 fixed-point accumulators: high byte = angle, low byte = fraction.
    // Coprime increments produce a long non-repeating tumble cycle.
    var spin_acc: u16 = 0; // Z-axis: screen-plane spin
    var tilt_acc: u16 = 0; // X-axis: along the logo length
    var yaw_acc: u16 = 0; // Y-axis: around the logo height
    var breath_acc: u16 = 0; // breathing zoom oscillator

    while (true) {
        waitVblank();
        clearBitmap();

        const spin: u8 = @truncate(spin_acc >> 8);
        const tilt: u8 = @truncate(tilt_acc >> 8);
        const yaw: u8 = @truncate(yaw_acc >> 8);
        const breath: u8 = @truncate(breath_acc >> 8);

        const scale: Fix16 = SCALE + fpMul(sin8(breath), BREATH_AMP);

        transformVertices(spin, tilt, yaw, scale);
        drawSegments();

        // Coprime fractional increments; full rotation periods at 50 fps:
        // spin ~9 s, tilt ~12 s, yaw ~7 s, breath ~16 s
        spin_acc +%= 139;
        tilt_acc +%= 107;
        yaw_acc +%= 181;
        breath_acc +%= 79;
    }
}
