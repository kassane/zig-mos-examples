// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! Minimal panic handler for MOS targets.
//!
//! std.debug.no_panic uses @trap() which LLVM-MOS lowers to abort() — an
//! undefined symbol on bare-metal targets.  All safety panics halt via an
//! infinite loop instead, which is the correct bare-metal behaviour.
//!
//! Usage: `pub const panic = @import("mos_panic");` in the root module.

pub fn call(_: []const u8, _: ?usize) noreturn {
    while (true) {}
}
pub fn sentinelMismatch(_: anytype, _: anytype) noreturn {
    while (true) {}
}
pub fn unwrapError(_: anyerror) noreturn {
    while (true) {}
}
pub fn outOfBounds(_: usize, _: usize) noreturn {
    while (true) {}
}
pub fn startGreaterThanEnd(_: usize, _: usize) noreturn {
    while (true) {}
}
pub fn inactiveUnionField(_: anytype, _: anytype) noreturn {
    while (true) {}
}
pub fn sliceCastLenRemainder(_: usize) noreturn {
    while (true) {}
}
pub fn reachedUnreachable() noreturn {
    while (true) {}
}
pub fn unwrapNull() noreturn {
    while (true) {}
}
pub fn castToNull() noreturn {
    while (true) {}
}
pub fn incorrectAlignment() noreturn {
    while (true) {}
}
pub fn invalidErrorCode() noreturn {
    while (true) {}
}
pub fn integerOutOfBounds() noreturn {
    while (true) {}
}
pub fn integerOverflow() noreturn {
    while (true) {}
}
pub fn shlOverflow() noreturn {
    while (true) {}
}
pub fn shrOverflow() noreturn {
    while (true) {}
}
pub fn divideByZero() noreturn {
    while (true) {}
}
pub fn exactDivisionRemainder() noreturn {
    while (true) {}
}
pub fn integerPartOutOfBounds() noreturn {
    while (true) {}
}
pub fn corruptSwitch() noreturn {
    while (true) {}
}
pub fn shiftRhsTooBig() noreturn {
    while (true) {}
}
pub fn invalidEnumValue() noreturn {
    while (true) {}
}
pub fn forLenMismatch() noreturn {
    while (true) {}
}
pub fn copyLenMismatch() noreturn {
    while (true) {}
}
pub fn memcpyAlias() noreturn {
    while (true) {}
}
pub fn noreturnReturned() noreturn {
    while (true) {}
}
