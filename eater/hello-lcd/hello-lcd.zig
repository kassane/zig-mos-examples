// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Scrolls "Hello, World!" across a 16x2 HD44780 LCD on Ben Eater's 6502 computer.
//! LCD driver (lcd_init / lcd_instruction / lcd_puts) lives in mos-platform/eater/lcd.c;
//! delay() lives in mos-platform/eater/delay.c — both compiled into libc by the SDK.
pub const panic = @import("mos_panic");

extern fn lcd_init() void;
extern fn lcd_instruction(insn: u8) void;
extern fn lcd_puts(str: [*:0]const u8) void;
extern fn delay(ms: c_uint) void;

const LCD_I_DDRAM: u8 = 0x80; // Set DDRAM address
const LCD_I_HOME: u8 = 0x02; // Move cursor to home position
const LCD_I_SHIFT_L: u8 = 0x18; // Shift display left

const message: [*:0]const u8 = "Hello, World!";
const message_len: c_int = 13;

pub export fn main() callconv(.c) void {
    lcd_init();

    // Write message just off-screen (DDRAM address 16 = second half of row 1)
    lcd_instruction(LCD_I_DDRAM | 16);
    lcd_puts(message);

    // Scroll the message across the visible 16-character window
    const count: c_int = 16 + message_len;
    var x: c_int = count;
    while (true) {
        delay(350);
        if (x <= 0) {
            lcd_instruction(LCD_I_HOME);
            x = count;
        } else {
            lcd_instruction(LCD_I_SHIFT_L);
            x -= 1;
        }
    }
}
