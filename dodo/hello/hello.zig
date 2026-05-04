// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
pub const panic = @import("mos_panic");
const dodo = @import("dodo");

pub export fn main() callconv(.c) void {
    dodo.CHECK_VERSION(1, 1, 0);
    dodo.CLEAR();
    dodo.SET_CURSOR(0, 0);
    dodo.DRAW_STRING("HELLO DODO!");
    dodo.DISPLAY();
    while (true) dodo.WAIT();
}
