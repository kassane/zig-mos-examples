// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
// Minimal PCE libpce wrapper for translate-c.
// Excludes bank.h (inline asm bank-switch stubs) and system.h (inline asm
// pce_cpu_irq_enable/disable) — Aro cannot lower inline asm function bodies.
// pce_irq_enable is declared here directly; its C signature translates cleanly.
// hardware.h volatile pointer-cast macros (#define IO_VCE_COLOR_INDEX ...) are
// silently dropped by Aro — use @ptrFromInt() in Zig source for MMIO registers.
#include <stdint.h>
#include <stdbool.h>
#include <pce/vce.h>
#include <pce/vdc.h>
void pce_irq_enable(uint8_t mask);
