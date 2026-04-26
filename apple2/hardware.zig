// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
// Apple IIe hardware register definitions (native Zig — translate-c cannot handle volatile casts).

fn mmio(addr: u16) *volatile u8 {
    return @ptrFromInt(addr);
}

// Keyboard
pub const KEYBOARD_DATA: *volatile u8 = mmio(0xC000);
pub const KEYBOARD_STROBE: *volatile u8 = mmio(0xC010);

// Text/graphics mode
pub const TEXTMODE_TEXT: *volatile u8 = mmio(0xC051);
pub const TEXTMODE_GRAPHICS: *volatile u8 = mmio(0xC050);
pub const MIXEDMODE_ON: *volatile u8 = mmio(0xC053);
pub const MIXEDMODE_OFF: *volatile u8 = mmio(0xC052);
pub const PAGE_PAGE2: *volatile u8 = mmio(0xC055);
pub const PAGE_PAGE1: *volatile u8 = mmio(0xC054);
pub const HIRES_ON: *volatile u8 = mmio(0xC057);
pub const HIRES_OFF: *volatile u8 = mmio(0xC056);

// Speaker / cassette
pub const SPEAKER_OUT: *volatile u8 = mmio(0xC030);

// Vblank (Apple //e)
pub const VBLANK: *volatile u8 = mmio(0xC019);

// Graphics pages
pub const TEXT_PAGE_1: [*]u8 = @ptrFromInt(0x0400);
pub const HIRES_PAGE_1: [*]u8 = @ptrFromInt(0x2000);
pub const HIRES_PAGE_2: [*]u8 = @ptrFromInt(0x4000);
