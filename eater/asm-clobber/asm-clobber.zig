// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Smoke-test for MOS inline-asm clobber declarations (a, x, y, c, v, p, memory).
//! Runs on Ben Eater's 6502 computer; output visible on the LCD.
pub const panic = @import("mos_panic");

extern fn lcd_init() void;
extern fn lcd_instruction(insn: u8) void;
extern fn lcd_puts(str: [*:0]const u8) void;

const LCD_I_HOME: u8 = 0x02;
const LCD_I_DDRAM: u8 = 0x80;

/// Adds two bytes using 6502 CLC/ADC and declares a + c clobbered.
fn asm_add(a: u8, b: u8) u8 {
    return asm volatile (
        \\clc
        \\adc %[b]
        : [ret] "=r" (-> u8),
        : [a] "r" (a),
          [b] "r" (b),
        : .{ .a = true, .c = true });
}

/// Stores zero to a ZP address using 6502 STA and declares memory + a clobbered.
fn asm_zero(addr: *volatile u8) void {
    asm volatile (
        \\lda #0
        \\sta (%[ptr])
        :
        : [ptr] "r" (addr),
        : .{ .a = true, .memory = true });
}

/// Reads the processor status register into a Zig u8 via PHP/PLA; clobbers a + p.
fn asm_get_p() u8 {
    return asm volatile (
        \\php
        \\pla
        : [ret] "=r" (-> u8),
        :
        : .{ .a = true, .p = true });
}

// Tiny itoa: writes decimal digits of n (0–255) into buf, returns slice length.
fn u8toa(n: u8, buf: *[4]u8) u8 {
    if (n == 0) {
        buf[0] = '0';
        buf[1] = 0;
        return 1;
    }
    var tmp = n;
    var i: u8 = 0;
    var tmp2: [3]u8 = undefined;
    while (tmp > 0) : (i += 1) {
        tmp2[i] = '0' + (tmp % 10);
        tmp = tmp / 10;
    }
    var j: u8 = 0;
    while (j < i) : (j += 1) {
        buf[j] = tmp2[i - 1 - j];
    }
    buf[j] = 0;
    return j;
}

pub export fn main() callconv(.c) void {
    lcd_init();

    // Test 1: asm_add — 40 + 2 = 42
    const sum = asm_add(40, 2);

    // Test 2: asm_zero — write 0 to a scratch ZP variable
    var scratch: u8 = 0xFF;
    asm_zero(&scratch);

    // Test 3: asm_get_p — fetch processor status
    const p = asm_get_p();

    // Line 1: "add=42 z=0"
    lcd_instruction(LCD_I_HOME);
    lcd_puts("add=");
    var buf: [4]u8 = undefined;
    _ = u8toa(sum, &buf);
    lcd_puts(@ptrCast(&buf));
    lcd_puts(" z=");
    _ = u8toa(scratch, &buf);
    lcd_puts(@ptrCast(&buf));

    // Line 2: "p=XX"
    lcd_instruction(LCD_I_DDRAM | 0x40); // row 2
    lcd_puts("p=");
    _ = u8toa(p, &buf);
    lcd_puts(@ptrCast(&buf));

    while (true) {}
}
