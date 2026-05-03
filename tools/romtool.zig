// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! romtool — NES / SNES pack · unpack · disassemble
//!
//! Usage: romtool <command> [options] <file> [args...]
//!
//! Commands:
//!   disasm   Disassemble ROM payload to stdout
//!   unpack   Extract ROM components to a directory
//!   pack     Assemble a ROM from components
//!   help     Show this help
//!
//! Run `romtool help <command>` for per-command options.

const std = @import("std");

// ── helpers ───────────────────────────────────────────────────────────────────

fn readU16Le(data: []const u8, off: usize) u16 {
    return @as(u16, data[off]) | (@as(u16, data[off + 1]) << 8);
}

fn readU24Le(data: []const u8, off: usize) u32 {
    return @as(u32, data[off]) |
        (@as(u32, data[off + 1]) << 8) |
        (@as(u32, data[off + 2]) << 16);
}

fn parseNum(s: []const u8) !u32 {
    if (std.mem.startsWith(u8, s, "0x") or std.mem.startsWith(u8, s, "0X"))
        return std.fmt.parseUnsigned(u32, s[2..], 16);
    if (std.mem.startsWith(u8, s, "$"))
        return std.fmt.parseUnsigned(u32, s[1..], 16);
    return std.fmt.parseUnsigned(u32, s, 10);
}

// ── help text ─────────────────────────────────────────────────────────────────

const help_main =
    \\romtool — NES / SNES pack · unpack · disassemble
    \\
    \\Usage: romtool <command> [options] <file> [args...]
    \\
    \\Commands:
    \\  disasm   Disassemble ROM payload to stdout
    \\  unpack   Extract ROM components to a directory
    \\  pack     Assemble a ROM from components
    \\  help     Show this help
    \\
    \\Run `romtool help <command>` for per-command options.
    \\
;

const help_disasm =
    \\romtool disasm [options] <file>
    \\
    \\Options:
    \\  --bank N      NES: disassemble PRG bank N only (0-based; default: all)
    \\  --offset N    Start disassembly at byte offset N (decimal or 0x hex)
    \\  --length N    Disassemble at most N bytes
    \\  --base ADDR   Override load address (decimal or 0x hex)
    \\  --cpu 6502    Force 6502 disassembler (default for NES)
    \\  --cpu 65816   Force 65816 disassembler (default for SNES)
    \\  -m, --m8      65816: assume M=1 (8-bit accumulator) throughout
    \\  -x, --x8      65816: assume X=1 (8-bit index) throughout
    \\
    \\Auto-detection:
    \\  .nes          — 6502, PRG at offset 16, bank size 16384
    \\  .sfc/.smc     — 65816 (M=1 X=1 unless overridden)
    \\  other/unknown — 6502 at offset 0, base $0000
    \\
;

const help_unpack =
    \\romtool unpack [options] <file> [outdir]
    \\
    \\Options:
    \\  --format nes|snes   Override auto-detection
    \\
    \\NES: writes header.txt, prg-bank-NN.bin, chr-bank-NN.bin
    \\SNES: writes header.txt, bank-NN.bin (32KB each, LoROM layout)
    \\
;

const help_pack =
    \\romtool pack <nes|snes> [options] -o <out> <inputs...>
    \\
    \\NES:  romtool pack nes [options] -o out.nes <prg.bin> [chr.bin]
    \\  --mapper N      Mapper number (default 0 = NROM)
    \\  --mirror h|v|4  Mirroring: h=horizontal v=vertical 4=4-screen (default h)
    \\  --battery       Set battery-backed SRAM flag
    \\  --nes2          Emit NES 2.0 header (default: iNES 1.0)
    \\
    \\SNES: romtool pack snes [options] -o out.sfc <bank-00.bin> [bank-01.bin ...]
    \\  --map lorom|fastrom|hirom   Map mode (default: auto-detect from data)
    \\  --title TITLE               21-char ROM title (overwrites header field)
    \\  --smc                       Prepend 512-byte SMC copier header
    \\  Inputs: one or more 32KB bank binaries (or a single flat ROM binary)
    \\  Checksum/complement are recomputed automatically.
    \\
;

fn helpExit() noreturn {
    std.debug.print("{s}", .{help_main});
    std.process.exit(0);
}

fn helpCmd(args: anytype) noreturn {
    const sub = args.next() orelse {
        std.debug.print("{s}", .{help_main});
        std.process.exit(0);
    };
    if (std.mem.eql(u8, sub, "disasm")) {
        std.debug.print("{s}", .{help_disasm});
    } else if (std.mem.eql(u8, sub, "unpack")) {
        std.debug.print("{s}", .{help_unpack});
    } else if (std.mem.eql(u8, sub, "pack")) {
        std.debug.print("{s}", .{help_pack});
    } else {
        std.debug.print("{s}", .{help_main});
    }
    std.process.exit(0);
}

// ── 6502 disassembler ─────────────────────────────────────────────────────────

const OpcodeMode = enum(u4) {
    imp,
    acc,
    imm,
    zp,
    zpx,
    zpy,
    abs_,
    absx,
    absy,
    ind,
    indx,
    indy,
    rel,

    fn size(m: OpcodeMode) usize {
        return switch (m) {
            .imp, .acc => 1,
            .imm, .zp, .zpx, .zpy, .indx, .indy, .rel => 2,
            .abs_, .absx, .absy, .ind => 3,
        };
    }
};

const OpcodeInfo = struct { mnem: [4]u8, mode: OpcodeMode };

fn op(m: *const [3]u8, mode: OpcodeMode) OpcodeInfo {
    return .{ .mnem = m.* ++ [1]u8{0}, .mode = mode };
}

const opcode_table: [256]OpcodeInfo = blk: {
    const M = OpcodeMode;
    var t = [_]OpcodeInfo{.{ .mnem = "???\x00".*, .mode = .imp }} ** 256;
    t[0x00] = op("BRK", .imp);
    t[0x01] = op("ORA", .indx);
    t[0x05] = op("ORA", .zp);
    t[0x06] = op("ASL", .zp);
    t[0x08] = op("PHP", .imp);
    t[0x09] = op("ORA", .imm);
    t[0x0A] = op("ASL", .acc);
    t[0x0D] = op("ORA", .abs_);
    t[0x0E] = op("ASL", .abs_);
    t[0x10] = op("BPL", .rel);
    t[0x11] = op("ORA", .indy);
    t[0x15] = op("ORA", .zpx);
    t[0x16] = op("ASL", .zpx);
    t[0x18] = op("CLC", .imp);
    t[0x19] = op("ORA", .absy);
    t[0x1D] = op("ORA", .absx);
    t[0x1E] = op("ASL", .absx);
    t[0x20] = op("JSR", .abs_);
    t[0x21] = op("AND", .indx);
    t[0x24] = op("BIT", .zp);
    t[0x25] = op("AND", .zp);
    t[0x26] = op("ROL", .zp);
    t[0x28] = op("PLP", .imp);
    t[0x29] = op("AND", .imm);
    t[0x2A] = op("ROL", .acc);
    t[0x2C] = op("BIT", .abs_);
    t[0x2D] = op("AND", .abs_);
    t[0x2E] = op("ROL", .abs_);
    t[0x30] = op("BMI", .rel);
    t[0x31] = op("AND", .indy);
    t[0x35] = op("AND", .zpx);
    t[0x36] = op("ROL", .zpx);
    t[0x38] = op("SEC", .imp);
    t[0x39] = op("AND", .absy);
    t[0x3D] = op("AND", .absx);
    t[0x3E] = op("ROL", .absx);
    t[0x40] = op("RTI", .imp);
    t[0x41] = op("EOR", .indx);
    t[0x45] = op("EOR", .zp);
    t[0x46] = op("LSR", .zp);
    t[0x48] = op("PHA", .imp);
    t[0x49] = op("EOR", .imm);
    t[0x4A] = op("LSR", .acc);
    t[0x4C] = op("JMP", .abs_);
    t[0x4D] = op("EOR", .abs_);
    t[0x4E] = op("LSR", .abs_);
    t[0x50] = op("BVC", .rel);
    t[0x51] = op("EOR", .indy);
    t[0x55] = op("EOR", .zpx);
    t[0x56] = op("LSR", .zpx);
    t[0x58] = op("CLI", .imp);
    t[0x59] = op("EOR", .absy);
    t[0x5D] = op("EOR", .absx);
    t[0x5E] = op("LSR", .absx);
    t[0x60] = op("RTS", .imp);
    t[0x61] = op("ADC", .indx);
    t[0x65] = op("ADC", .zp);
    t[0x66] = op("ROR", .zp);
    t[0x68] = op("PLA", .imp);
    t[0x69] = op("ADC", .imm);
    t[0x6A] = op("ROR", .acc);
    t[0x6C] = op("JMP", .ind);
    t[0x6D] = op("ADC", .abs_);
    t[0x6E] = op("ROR", .abs_);
    t[0x70] = op("BVS", .rel);
    t[0x71] = op("ADC", .indy);
    t[0x75] = op("ADC", .zpx);
    t[0x76] = op("ROR", .zpx);
    t[0x78] = op("SEI", .imp);
    t[0x79] = op("ADC", .absy);
    t[0x7D] = op("ADC", .absx);
    t[0x7E] = op("ROR", .absx);
    t[0x81] = op("STA", .indx);
    t[0x84] = op("STY", .zp);
    t[0x85] = op("STA", .zp);
    t[0x86] = op("STX", .zp);
    t[0x88] = op("DEY", .imp);
    t[0x8A] = op("TXA", .imp);
    t[0x8C] = op("STY", .abs_);
    t[0x8D] = op("STA", .abs_);
    t[0x8E] = op("STX", .abs_);
    t[0x90] = op("BCC", .rel);
    t[0x91] = op("STA", .indy);
    t[0x94] = op("STY", .zpx);
    t[0x95] = op("STA", .zpx);
    t[0x96] = op("STX", .zpy);
    t[0x98] = op("TYA", .imp);
    t[0x99] = op("STA", .absy);
    t[0x9A] = op("TXS", .imp);
    t[0x9D] = op("STA", .absx);
    t[0xA0] = op("LDY", .imm);
    t[0xA1] = op("LDA", .indx);
    t[0xA2] = op("LDX", .imm);
    t[0xA4] = op("LDY", .zp);
    t[0xA5] = op("LDA", .zp);
    t[0xA6] = op("LDX", .zp);
    t[0xA8] = op("TAY", .imp);
    t[0xA9] = op("LDA", .imm);
    t[0xAA] = op("TAX", .imp);
    t[0xAC] = op("LDY", .abs_);
    t[0xAD] = op("LDA", .abs_);
    t[0xAE] = op("LDX", .abs_);
    t[0xB0] = op("BCS", .rel);
    t[0xB1] = op("LDA", .indy);
    t[0xB4] = op("LDY", .zpx);
    t[0xB5] = op("LDA", .zpx);
    t[0xB6] = op("LDX", .zpy);
    t[0xB8] = op("CLV", .imp);
    t[0xB9] = op("LDA", .absy);
    t[0xBA] = op("TSX", .imp);
    t[0xBC] = op("LDY", .absx);
    t[0xBD] = op("LDA", .absx);
    t[0xBE] = op("LDX", .absy);
    t[0xC0] = op("CPY", .imm);
    t[0xC1] = op("CMP", .indx);
    t[0xC4] = op("CPY", .zp);
    t[0xC5] = op("CMP", .zp);
    t[0xC6] = op("DEC", .zp);
    t[0xC8] = op("INY", .imp);
    t[0xC9] = op("CMP", .imm);
    t[0xCA] = op("DEX", .imp);
    t[0xCC] = op("CPY", .abs_);
    t[0xCD] = op("CMP", .abs_);
    t[0xCE] = op("DEC", .abs_);
    t[0xD0] = op("BNE", .rel);
    t[0xD1] = op("CMP", .indy);
    t[0xD5] = op("CMP", .zpx);
    t[0xD6] = op("DEC", .zpx);
    t[0xD8] = op("CLD", .imp);
    t[0xD9] = op("CMP", .absy);
    t[0xDD] = op("CMP", .absx);
    t[0xDE] = op("DEC", .absx);
    t[0xE0] = op("CPX", .imm);
    t[0xE1] = op("SBC", .indx);
    t[0xE4] = op("CPX", .zp);
    t[0xE5] = op("SBC", .zp);
    t[0xE6] = op("INC", .zp);
    t[0xE8] = op("INX", .imp);
    t[0xE9] = op("SBC", .imm);
    t[0xEA] = op("NOP", .imp);
    t[0xEC] = op("CPX", .abs_);
    t[0xED] = op("SBC", .abs_);
    t[0xEE] = op("INC", .abs_);
    t[0xF0] = op("BEQ", .rel);
    t[0xF1] = op("SBC", .indy);
    t[0xF5] = op("SBC", .zpx);
    t[0xF6] = op("INC", .zpx);
    t[0xF8] = op("SED", .imp);
    t[0xF9] = op("SBC", .absy);
    t[0xFD] = op("SBC", .absx);
    t[0xFE] = op("INC", .absx);
    _ = M;
    break :blk t;
};

fn disasm6502(out: anytype, data: []const u8, load_addr: u16) void {
    var i: usize = 0;
    while (i < data.len) {
        const byte = data[i];
        const info = opcode_table[byte];
        const sz = info.mode.size();
        const addr = load_addr +% @as(u16, @truncate(i));
        const mnem = std.mem.sliceTo(&info.mnem, 0);

        if (i + sz > data.len) {
            out.print("  ${x:0>4}  {x:0>2}              ???\n", .{ addr, byte }) catch {};
            break;
        }

        switch (sz) {
            1 => out.print("  ${x:0>4}  {x:0>2}           ", .{ addr, byte }) catch {},
            2 => out.print("  ${x:0>4}  {x:0>2} {x:0>2}        ", .{ addr, byte, data[i + 1] }) catch {},
            3 => out.print("  ${x:0>4}  {x:0>2} {x:0>2} {x:0>2}     ", .{ addr, byte, data[i + 1], data[i + 2] }) catch {},
            else => unreachable,
        }

        switch (info.mode) {
            .imp => out.print("{s}\n", .{mnem}) catch {},
            .acc => out.print("{s} A\n", .{mnem}) catch {},
            .imm => out.print("{s} #${x:0>2}\n", .{ mnem, data[i + 1] }) catch {},
            .zp => out.print("{s} ${x:0>2}\n", .{ mnem, data[i + 1] }) catch {},
            .zpx => out.print("{s} ${x:0>2},X\n", .{ mnem, data[i + 1] }) catch {},
            .zpy => out.print("{s} ${x:0>2},Y\n", .{ mnem, data[i + 1] }) catch {},
            .abs_ => out.print("{s} ${x:0>4}\n", .{ mnem, readU16Le(data, i + 1) }) catch {},
            .absx => out.print("{s} ${x:0>4},X\n", .{ mnem, readU16Le(data, i + 1) }) catch {},
            .absy => out.print("{s} ${x:0>4},Y\n", .{ mnem, readU16Le(data, i + 1) }) catch {},
            .ind => out.print("{s} (${x:0>4})\n", .{ mnem, readU16Le(data, i + 1) }) catch {},
            .indx => out.print("{s} (${x:0>2},X)\n", .{ mnem, data[i + 1] }) catch {},
            .indy => out.print("{s} (${x:0>2}),Y\n", .{ mnem, data[i + 1] }) catch {},
            .rel => {
                const off: i8 = @bitCast(data[i + 1]);
                const target = addr +% 2 +% @as(u16, @bitCast(@as(i16, off)));
                out.print("{s} ${x:0>4}\n", .{ mnem, target }) catch {};
            },
        }

        i += sz;
    }
}

// ── 65816 disassembler ────────────────────────────────────────────────────────

// 65816 addressing modes (superset of 6502 + long + stack-relative)
const Mode816 = enum {
    imp, // 1 byte: no operand
    imm8, // 2 bytes: #imm8
    imm16, // 3 bytes: #imm16
    immM, // 2 or 3 bytes depending on M flag
    immX, // 2 or 3 bytes depending on X flag
    dp, // 2 bytes: dp
    dpx, // 2 bytes: dp,X
    dpy, // 2 bytes: dp,Y
    dpind, // 2 bytes: (dp)
    dpindx, // 2 bytes: (dp,X)
    dpindy, // 2 bytes: (dp),Y
    dpindl, // 2 bytes: [dp]
    dpindly, // 2 bytes: [dp],Y
    abs_, // 3 bytes: abs
    absx, // 3 bytes: abs,X
    absy, // 3 bytes: abs,Y
    absind, // 3 bytes: (abs)
    absindx, // 3 bytes: (abs,X)
    long_, // 4 bytes: long
    longx, // 4 bytes: long,X
    rel8, // 2 bytes: rel8
    rel16, // 3 bytes: rel16
    sr, // 2 bytes: sr,S
    sriy, // 2 bytes: (sr,S),Y
    blkmov, // 3 bytes: srcbank,dstbank (MVN/MVP)
};

const Op816 = struct { mnem: []const u8, mode: Mode816 };

fn op816(m: []const u8, mode: Mode816) Op816 {
    return .{ .mnem = m, .mode = mode };
}

fn modeBytes816(mode: Mode816, m_flag: bool, x_flag: bool) usize {
    return switch (mode) {
        .imp => 1,
        .imm8, .dp, .dpx, .dpy, .dpind, .dpindx, .dpindy, .dpindl, .dpindly, .rel8, .sr, .sriy => 2,
        .immM => if (m_flag) 2 else 3,
        .immX => if (x_flag) 2 else 3,
        .abs_, .absx, .absy, .absind, .absindx, .rel16, .blkmov, .imm16 => 3,
        .long_, .longx => 4,
    };
}

// Returns null for truly unknown opcodes
fn lookup816(byte: u8) ?Op816 {
    return switch (byte) {
        // BRK/COP
        0x00 => op816("BRK", .imm8),
        0x02 => op816("COP", .imm8),
        // ORA group
        0x01 => op816("ORA", .dpindx),
        0x03 => op816("ORA", .sr),
        0x05 => op816("ORA", .dp),
        0x07 => op816("ORA", .dpindl),
        0x09 => op816("ORA", .immM),
        0x0D => op816("ORA", .abs_),
        0x0F => op816("ORA", .long_),
        0x11 => op816("ORA", .dpindy),
        0x12 => op816("ORA", .dpind),
        0x13 => op816("ORA", .sriy),
        0x15 => op816("ORA", .dpx),
        0x17 => op816("ORA", .dpindly),
        0x19 => op816("ORA", .absy),
        0x1D => op816("ORA", .absx),
        0x1F => op816("ORA", .longx),
        // ASL group
        0x06 => op816("ASL", .dp),
        0x0A => op816("ASL", .imp),
        0x0E => op816("ASL", .abs_),
        0x16 => op816("ASL", .dpx),
        0x1E => op816("ASL", .absx),
        // Branch
        0x10 => op816("BPL", .rel8),
        0x30 => op816("BMI", .rel8),
        0x50 => op816("BVC", .rel8),
        0x70 => op816("BVS", .rel8),
        0x90 => op816("BCC", .rel8),
        0xB0 => op816("BCS", .rel8),
        0xD0 => op816("BNE", .rel8),
        0xF0 => op816("BEQ", .rel8),
        0x80 => op816("BRA", .rel8),
        0x82 => op816("BRL", .rel16),
        // Stack
        0x08 => op816("PHP", .imp),
        0x28 => op816("PLP", .imp),
        0x48 => op816("PHA", .imp),
        0x68 => op816("PLA", .imp),
        0xDA => op816("PHX", .imp),
        0xFA => op816("PLX", .imp),
        0x5A => op816("PHY", .imp),
        0x7A => op816("PLY", .imp),
        0x8B => op816("PHB", .imp),
        0xAB => op816("PLB", .imp),
        0x0B => op816("PHD", .imp),
        0x2B => op816("PLD", .imp),
        0x4B => op816("PHK", .imp),
        // PEA/PEI/PER
        0xF4 => op816("PEA", .imm16),
        0xD4 => op816("PEI", .dp),
        0x62 => op816("PER", .rel16),
        // JSR/JSL/RTS/RTL/RTI
        0x20 => op816("JSR", .abs_),
        0x22 => op816("JSL", .long_),
        0x60 => op816("RTS", .imp),
        0x6B => op816("RTL", .imp),
        0x40 => op816("RTI", .imp),
        // JMP/JML
        0x4C => op816("JMP", .abs_),
        0x6C => op816("JMP", .absind),
        0x7C => op816("JMP", .absindx),
        0x5C => op816("JML", .long_),
        0xDC => op816("JML", .absind),
        // AND group
        0x21 => op816("AND", .dpindx),
        0x23 => op816("AND", .sr),
        0x24 => op816("BIT", .dp),
        0x25 => op816("AND", .dp),
        0x27 => op816("AND", .dpindl),
        0x29 => op816("AND", .immM),
        0x2C => op816("BIT", .abs_),
        0x2D => op816("AND", .abs_),
        0x2F => op816("AND", .long_),
        0x31 => op816("AND", .dpindy),
        0x32 => op816("AND", .dpind),
        0x33 => op816("AND", .sriy),
        0x34 => op816("BIT", .dpx),
        0x35 => op816("AND", .dpx),
        0x37 => op816("AND", .dpindly),
        0x39 => op816("AND", .absy),
        0x3C => op816("BIT", .absx),
        0x3D => op816("AND", .absx),
        0x3F => op816("AND", .longx),
        // ROL/ROR
        0x26 => op816("ROL", .dp),
        0x2A => op816("ROL", .imp),
        0x2E => op816("ROL", .abs_),
        0x36 => op816("ROL", .dpx),
        0x3E => op816("ROL", .absx),
        0x66 => op816("ROR", .dp),
        0x6A => op816("ROR", .imp),
        0x6E => op816("ROR", .abs_),
        0x76 => op816("ROR", .dpx),
        0x7E => op816("ROR", .absx),
        // LSR
        0x46 => op816("LSR", .dp),
        0x4A => op816("LSR", .imp),
        0x4E => op816("LSR", .abs_),
        0x56 => op816("LSR", .dpx),
        0x5E => op816("LSR", .absx),
        // EOR group
        0x41 => op816("EOR", .dpindx),
        0x43 => op816("EOR", .sr),
        0x45 => op816("EOR", .dp),
        0x47 => op816("EOR", .dpindl),
        0x49 => op816("EOR", .immM),
        0x4D => op816("EOR", .abs_),
        0x4F => op816("EOR", .long_),
        0x51 => op816("EOR", .dpindy),
        0x52 => op816("EOR", .dpind),
        0x53 => op816("EOR", .sriy),
        0x55 => op816("EOR", .dpx),
        0x57 => op816("EOR", .dpindly),
        0x59 => op816("EOR", .absy),
        0x5D => op816("EOR", .absx),
        0x5F => op816("EOR", .longx),
        // ADC group
        0x61 => op816("ADC", .dpindx),
        0x63 => op816("ADC", .sr),
        0x65 => op816("ADC", .dp),
        0x67 => op816("ADC", .dpindl),
        0x69 => op816("ADC", .immM),
        0x6D => op816("ADC", .abs_),
        0x6F => op816("ADC", .long_),
        0x71 => op816("ADC", .dpindy),
        0x72 => op816("ADC", .dpind),
        0x73 => op816("ADC", .sriy),
        0x75 => op816("ADC", .dpx),
        0x77 => op816("ADC", .dpindly),
        0x79 => op816("ADC", .absy),
        0x7D => op816("ADC", .absx),
        0x7F => op816("ADC", .longx),
        // STA group
        0x81 => op816("STA", .dpindx),
        0x83 => op816("STA", .sr),
        0x85 => op816("STA", .dp),
        0x87 => op816("STA", .dpindl),
        0x8D => op816("STA", .abs_),
        0x8F => op816("STA", .long_),
        0x91 => op816("STA", .dpindy),
        0x92 => op816("STA", .dpind),
        0x93 => op816("STA", .sriy),
        0x95 => op816("STA", .dpx),
        0x97 => op816("STA", .dpindly),
        0x99 => op816("STA", .absy),
        0x9D => op816("STA", .absx),
        0x9F => op816("STA", .longx),
        // LDA group
        0xA1 => op816("LDA", .dpindx),
        0xA3 => op816("LDA", .sr),
        0xA5 => op816("LDA", .dp),
        0xA7 => op816("LDA", .dpindl),
        0xA9 => op816("LDA", .immM),
        0xAD => op816("LDA", .abs_),
        0xAF => op816("LDA", .long_),
        0xB1 => op816("LDA", .dpindy),
        0xB2 => op816("LDA", .dpind),
        0xB3 => op816("LDA", .sriy),
        0xB5 => op816("LDA", .dpx),
        0xB7 => op816("LDA", .dpindly),
        0xB9 => op816("LDA", .absy),
        0xBD => op816("LDA", .absx),
        0xBF => op816("LDA", .longx),
        // CMP group
        0xC1 => op816("CMP", .dpindx),
        0xC3 => op816("CMP", .sr),
        0xC5 => op816("CMP", .dp),
        0xC7 => op816("CMP", .dpindl),
        0xC9 => op816("CMP", .immM),
        0xCD => op816("CMP", .abs_),
        0xCF => op816("CMP", .long_),
        0xD1 => op816("CMP", .dpindy),
        0xD2 => op816("CMP", .dpind),
        0xD3 => op816("CMP", .sriy),
        0xD5 => op816("CMP", .dpx),
        0xD7 => op816("CMP", .dpindly),
        0xD9 => op816("CMP", .absy),
        0xDD => op816("CMP", .absx),
        0xDF => op816("CMP", .longx),
        // SBC group
        0xE1 => op816("SBC", .dpindx),
        0xE3 => op816("SBC", .sr),
        0xE5 => op816("SBC", .dp),
        0xE7 => op816("SBC", .dpindl),
        0xE9 => op816("SBC", .immM),
        0xED => op816("SBC", .abs_),
        0xEF => op816("SBC", .long_),
        0xF1 => op816("SBC", .dpindy),
        0xF2 => op816("SBC", .dpind),
        0xF3 => op816("SBC", .sriy),
        0xF5 => op816("SBC", .dpx),
        0xF7 => op816("SBC", .dpindly),
        0xF9 => op816("SBC", .absy),
        0xFD => op816("SBC", .absx),
        0xFF => op816("SBC", .longx),
        // STX/STY/STZ
        0x84 => op816("STY", .dp),
        0x86 => op816("STX", .dp),
        0x8C => op816("STY", .abs_),
        0x8E => op816("STX", .abs_),
        0x94 => op816("STY", .dpx),
        0x96 => op816("STX", .dpy),
        0x64 => op816("STZ", .dp),
        0x74 => op816("STZ", .dpx),
        0x9C => op816("STZ", .abs_),
        0x9E => op816("STZ", .absx),
        // LDX/LDY
        0xA0 => op816("LDY", .immX),
        0xA2 => op816("LDX", .immX),
        0xA4 => op816("LDY", .dp),
        0xA6 => op816("LDX", .dp),
        0xAC => op816("LDY", .abs_),
        0xAE => op816("LDX", .abs_),
        0xB4 => op816("LDY", .dpx),
        0xB6 => op816("LDX", .dpy),
        0xBC => op816("LDY", .absx),
        0xBE => op816("LDX", .absy),
        // CPX/CPY
        0xC0 => op816("CPY", .immX),
        0xC4 => op816("CPY", .dp),
        0xCC => op816("CPY", .abs_),
        0xE0 => op816("CPX", .immX),
        0xE4 => op816("CPX", .dp),
        0xEC => op816("CPX", .abs_),
        // INC/DEC
        0xC6 => op816("DEC", .dp),
        0xCA => op816("DEX", .imp),
        0xCE => op816("DEC", .abs_),
        0xD6 => op816("DEC", .dpx),
        0xDE => op816("DEC", .absx),
        0x1A => op816("INC", .imp),
        0x3A => op816("DEC", .imp),
        0xE6 => op816("INC", .dp),
        0xE8 => op816("INX", .imp),
        0xEE => op816("INC", .abs_),
        0xF6 => op816("INC", .dpx),
        0xFE => op816("INC", .absx),
        // INY/DEY
        0xC8 => op816("INY", .imp),
        0x88 => op816("DEY", .imp),
        // Transfers
        0xAA => op816("TAX", .imp),
        0xA8 => op816("TAY", .imp),
        0x8A => op816("TXA", .imp),
        0x98 => op816("TYA", .imp),
        0x9A => op816("TXS", .imp),
        0xBA => op816("TSX", .imp),
        0x5B => op816("TCD", .imp),
        0x7B => op816("TDC", .imp),
        0x1B => op816("TCS", .imp),
        0x3B => op816("TSC", .imp),
        0x9B => op816("TXY", .imp),
        0xBB => op816("TYX", .imp),
        // Flags
        0x18 => op816("CLC", .imp),
        0x38 => op816("SEC", .imp),
        0x58 => op816("CLI", .imp),
        0x78 => op816("SEI", .imp),
        0xB8 => op816("CLV", .imp),
        0xD8 => op816("CLD", .imp),
        0xF8 => op816("SED", .imp),
        // rep/sep
        0xC2 => op816("REP", .imm8),
        0xE2 => op816("SEP", .imm8),
        // XBA/XCE
        0xEB => op816("XBA", .imp),
        0xFB => op816("XCE", .imp),
        // WAI/STP
        0xCB => op816("WAI", .imp),
        0xDB => op816("STP", .imp),
        // NOP
        0xEA => op816("NOP", .imp),
        // MVN/MVP
        0x54 => op816("MVN", .blkmov),
        0x44 => op816("MVP", .blkmov),
        // TSB/TRB
        0x04 => op816("TSB", .dp),
        0x0C => op816("TSB", .abs_),
        0x14 => op816("TRB", .dp),
        0x1C => op816("TRB", .abs_),
        // WDM (one reserved byte)
        0x42 => op816("WDM", .imm8),
        else => null,
    };
}

fn disasm65816(out: anytype, data: []const u8, load_addr: u32, init_m: bool, init_x: bool) void {
    var i: usize = 0;
    var m_flag = init_m; // true = 8-bit accumulator
    var x_flag = init_x; // true = 8-bit index

    while (i < data.len) {
        const byte = data[i];
        const addr = load_addr +% @as(u32, @truncate(i));

        const maybe_op = lookup816(byte);
        if (maybe_op == null) {
            out.print("  ${x:0>6}  {x:0>2}              ???\n", .{ addr, byte }) catch {};
            i += 1;
            continue;
        }
        const inf = maybe_op.?;
        const sz = modeBytes816(inf.mode, m_flag, x_flag);

        if (i + sz > data.len) {
            out.print("  ${x:0>6}  {x:0>2}              ???\n", .{ addr, byte }) catch {};
            break;
        }

        // Raw bytes (up to 4)
        switch (sz) {
            1 => out.print("  ${x:0>6}  {x:0>2}           ", .{ addr, byte }) catch {},
            2 => out.print("  ${x:0>6}  {x:0>2} {x:0>2}        ", .{ addr, byte, data[i + 1] }) catch {},
            3 => out.print("  ${x:0>6}  {x:0>2} {x:0>2} {x:0>2}     ", .{ addr, byte, data[i + 1], data[i + 2] }) catch {},
            4 => out.print("  ${x:0>6}  {x:0>2} {x:0>2} {x:0>2} {x:0>2}  ", .{ addr, byte, data[i + 1], data[i + 2], data[i + 3] }) catch {},
            else => unreachable,
        }

        // Operand formatting
        switch (inf.mode) {
            .imp => out.print("{s}\n", .{inf.mnem}) catch {},
            .imm8 => out.print("{s} #${x:0>2}\n", .{ inf.mnem, data[i + 1] }) catch {},
            .imm16 => out.print("{s} #${x:0>4}\n", .{ inf.mnem, readU16Le(data, i + 1) }) catch {},
            .immM => {
                if (m_flag)
                    out.print("{s} #${x:0>2}\n", .{ inf.mnem, data[i + 1] }) catch {}
                else
                    out.print("{s} #${x:0>4}\n", .{ inf.mnem, readU16Le(data, i + 1) }) catch {};
            },
            .immX => {
                if (x_flag)
                    out.print("{s} #${x:0>2}\n", .{ inf.mnem, data[i + 1] }) catch {}
                else
                    out.print("{s} #${x:0>4}\n", .{ inf.mnem, readU16Le(data, i + 1) }) catch {};
            },
            .dp => out.print("{s} ${x:0>2}\n", .{ inf.mnem, data[i + 1] }) catch {},
            .dpind => out.print("{s} (${x:0>2})\n", .{ inf.mnem, data[i + 1] }) catch {},
            .dpindl => out.print("{s} [${x:0>2}]\n", .{ inf.mnem, data[i + 1] }) catch {},
            .dpx => out.print("{s} ${x:0>2},X\n", .{ inf.mnem, data[i + 1] }) catch {},
            .dpy => out.print("{s} ${x:0>2},Y\n", .{ inf.mnem, data[i + 1] }) catch {},
            .dpindx => out.print("{s} (${x:0>2},X)\n", .{ inf.mnem, data[i + 1] }) catch {},
            .dpindy => out.print("{s} (${x:0>2}),Y\n", .{ inf.mnem, data[i + 1] }) catch {},
            .dpindly => out.print("{s} [${x:0>2}],Y\n", .{ inf.mnem, data[i + 1] }) catch {},
            .sr => out.print("{s} ${x:0>2},S\n", .{ inf.mnem, data[i + 1] }) catch {},
            .sriy => out.print("{s} (${x:0>2},S),Y\n", .{ inf.mnem, data[i + 1] }) catch {},
            .abs_ => out.print("{s} ${x:0>4}\n", .{ inf.mnem, readU16Le(data, i + 1) }) catch {},
            .absx => out.print("{s} ${x:0>4},X\n", .{ inf.mnem, readU16Le(data, i + 1) }) catch {},
            .absy => out.print("{s} ${x:0>4},Y\n", .{ inf.mnem, readU16Le(data, i + 1) }) catch {},
            .absind => out.print("{s} (${x:0>4})\n", .{ inf.mnem, readU16Le(data, i + 1) }) catch {},
            .absindx => out.print("{s} (${x:0>4},X)\n", .{ inf.mnem, readU16Le(data, i + 1) }) catch {},
            .long_ => out.print("{s} ${x:0>6}\n", .{ inf.mnem, readU24Le(data, i + 1) }) catch {},
            .longx => out.print("{s} ${x:0>6},X\n", .{ inf.mnem, readU24Le(data, i + 1) }) catch {},
            .rel8 => {
                const off: i8 = @bitCast(data[i + 1]);
                const target = @as(u32, @intCast(@as(i64, addr) + 2 + @as(i64, off)));
                out.print("{s} ${x:0>4}\n", .{ inf.mnem, @as(u16, @truncate(target)) }) catch {};
            },
            .rel16 => {
                const off: i16 = @bitCast(readU16Le(data, i + 1));
                const target = @as(u32, @intCast(@as(i64, addr) + 3 + @as(i64, off)));
                out.print("{s} ${x:0>4}\n", .{ inf.mnem, @as(u16, @truncate(target)) }) catch {};
            },
            .blkmov => out.print("{s} ${x:0>2},${x:0>2}\n", .{ inf.mnem, data[i + 2], data[i + 1] }) catch {},
        }

        // Track M/X flag changes from REP/SEP
        if (byte == 0xC2 and sz >= 2) { // REP
            const mask = data[i + 1];
            if (mask & 0x20 != 0) {
                m_flag = false;
                out.print("  ; M=0\n", .{}) catch {};
            }
            if (mask & 0x10 != 0) {
                x_flag = false;
                out.print("  ; X=0\n", .{}) catch {};
            }
        }
        if (byte == 0xE2 and sz >= 2) { // SEP
            const mask = data[i + 1];
            if (mask & 0x20 != 0) {
                m_flag = true;
                out.print("  ; M=1\n", .{}) catch {};
            }
            if (mask & 0x10 != 0) {
                x_flag = true;
                out.print("  ; X=1\n", .{}) catch {};
            }
        }

        i += sz;
    }
}

// ── format detection ──────────────────────────────────────────────────────────

const RomFormat = enum { nes, snes, raw };

fn detectFormat(path: []const u8, data: []const u8) RomFormat {
    if (data.len >= 4 and std.mem.eql(u8, data[0..4], "NES\x1a")) return .nes;
    const ext = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(ext, ".nes")) return .nes;
    if (std.ascii.eqlIgnoreCase(ext, ".sfc")) return .snes;
    if (std.ascii.eqlIgnoreCase(ext, ".smc")) return .snes;
    return .raw;
}

// ── disasm command ────────────────────────────────────────────────────────────

fn cmdDisasm(alloc: std.mem.Allocator, io: std.Io, args: anytype) !void {
    var file_path: ?[]const u8 = null;
    var bank_opt: ?usize = null;
    var offset_opt: ?usize = null;
    var length_opt: ?usize = null;
    var base_opt: ?u32 = null;
    var cpu_opt: ?[]const u8 = null;
    var force_m8 = false;
    var force_x8 = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--bank")) {
            const val = args.next() orelse {
                std.debug.print("romtool: --bank requires a value\n", .{});
                std.process.exit(1);
            };
            bank_opt = std.fmt.parseUnsigned(usize, val, 10) catch {
                std.debug.print("romtool: --bank: invalid number '{s}'\n", .{val});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--offset")) {
            const val = args.next() orelse {
                std.debug.print("romtool: --offset requires a value\n", .{});
                std.process.exit(1);
            };
            offset_opt = @intCast(parseNum(val) catch {
                std.debug.print("romtool: --offset: invalid number '{s}'\n", .{val});
                std.process.exit(1);
            });
        } else if (std.mem.eql(u8, arg, "--length")) {
            const val = args.next() orelse {
                std.debug.print("romtool: --length requires a value\n", .{});
                std.process.exit(1);
            };
            length_opt = @intCast(parseNum(val) catch {
                std.debug.print("romtool: --length: invalid number '{s}'\n", .{val});
                std.process.exit(1);
            });
        } else if (std.mem.eql(u8, arg, "--base")) {
            const val = args.next() orelse {
                std.debug.print("romtool: --base requires a value\n", .{});
                std.process.exit(1);
            };
            base_opt = parseNum(val) catch {
                std.debug.print("romtool: --base: invalid address '{s}'\n", .{val});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--cpu")) {
            cpu_opt = args.next() orelse {
                std.debug.print("romtool: --cpu requires a value\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--m8")) {
            force_m8 = true;
        } else if (std.mem.eql(u8, arg, "-x") or std.mem.eql(u8, arg, "--x8")) {
            force_x8 = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("romtool: disasm: unknown option '{s}'\n", .{arg});
            std.debug.print("{s}", .{help_disasm});
            std.process.exit(1);
        } else {
            file_path = arg;
        }
    }

    const path = file_path orelse {
        std.debug.print("romtool: disasm: no file specified\n", .{});
        std.debug.print("{s}", .{help_disasm});
        std.process.exit(1);
    };

    const cwd = std.Io.Dir.cwd();
    const data = cwd.readFileAlloc(io, path, alloc, .unlimited) catch |err| {
        std.debug.print("romtool: {s}: {s}\n", .{ path, @errorName(err) });
        std.process.exit(1);
    };
    defer alloc.free(data);

    const fmt = detectFormat(path, data);

    // Determine CPU
    const use_65816 = if (cpu_opt) |c|
        std.mem.eql(u8, c, "65816")
    else
        fmt == .snes;

    var stdout_buf: [4096]u8 = undefined;
    var stdout_fw = std.Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &stdout_fw.interface;

    if (use_65816) {
        // SNES: header is either 512-byte SMC header or none
        const has_smc_header = fmt == .snes and data.len % 1024 == 512;
        const hdr_size: usize = if (has_smc_header) 512 else 0;
        var payload = data[hdr_size..];

        // Optional bank selection (32KB banks, same as unpack output).
        const bank_size_snes: usize = 32768;
        if (bank_opt) |b| {
            const start = b * bank_size_snes;
            if (start >= payload.len) {
                std.debug.print("romtool: bank {d} out of range\n", .{b});
                std.process.exit(1);
            }
            const end = @min(start + bank_size_snes, payload.len);
            payload = payload[start..end];
        }

        const offset: usize = offset_opt orelse 0;
        if (offset >= payload.len and offset != 0) {
            std.debug.print("romtool: --offset 0x{x} is past end of payload ({d} bytes)\n", .{ offset, payload.len });
            std.process.exit(1);
        }
        payload = payload[offset..];
        const base_addr: u32 = blk: {
            var base: u32 = base_opt orelse 0x008000;
            base +%= @truncate(offset);
            break :blk base;
        };

        if (length_opt) |l| {
            if (l < payload.len) payload = payload[0..l];
        }

        stdout.print("; 65816 disassembly of {s}  base=${x:0>6}\n", .{ path, base_addr }) catch {};
        disasm65816(stdout, payload, base_addr, force_m8 or true, force_x8 or true);
    } else {
        // 6502 path
        var prg_data: []const u8 = data;
        var load_addr: u16 = 0x0000;

        switch (fmt) {
            .nes => {
                if (data.len < 16) {
                    std.debug.print("romtool: {s}: NES header too small\n", .{path});
                    std.process.exit(1);
                }
                const prg_banks: usize = data[4];
                const bank_size: usize = 16384;
                prg_data = data[16..];
                // Clamp to PRG region
                const prg_end = @min(prg_banks * bank_size, prg_data.len);
                prg_data = prg_data[0..prg_end];
                if (bank_opt) |b| {
                    const start = b * bank_size;
                    if (start >= prg_data.len) {
                        std.debug.print("romtool: bank {d} out of range (max {d})\n", .{ b, prg_banks - 1 });
                        std.process.exit(1);
                    }
                    const end = @min(start + bank_size, prg_data.len);
                    prg_data = prg_data[start..end];
                    // Last bank is always fixed at $C000; swappable banks map to $8000.
                    load_addr = if (base_opt) |base| @truncate(base) else if (b == prg_banks - 1) 0xC000 else 0x8000;
                } else {
                    load_addr = if (base_opt) |base| @truncate(base) else 0x8000;
                }
            },
            else => {
                load_addr = if (base_opt) |b| @truncate(b) else 0x0000;
            },
        }

        const offset: usize = offset_opt orelse 0;
        if (offset >= prg_data.len and offset != 0) {
            std.debug.print("romtool: --offset 0x{x} is past end of payload ({d} bytes)\n", .{ offset, prg_data.len });
            std.process.exit(1);
        }
        prg_data = prg_data[offset..];
        load_addr +%= @truncate(offset); // advance display address to match skipped bytes

        if (length_opt) |l| {
            if (l < prg_data.len) prg_data = prg_data[0..l];
        }

        stdout.print("; 6502 disassembly of {s}  base=${x:0>4}\n", .{ path, load_addr }) catch {};
        disasm6502(stdout, prg_data, load_addr);
    }

    stdout_fw.flush() catch {};
}

// ── unpack command ────────────────────────────────────────────────────────────

fn cmdUnpack(alloc: std.mem.Allocator, io: std.Io, args: anytype) !void {
    var file_path: ?[]const u8 = null;
    var outdir_opt: ?[]const u8 = null;
    var format_override: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--format")) {
            format_override = args.next() orelse {
                std.debug.print("romtool: --format requires a value\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("romtool: unpack: unknown option '{s}'\n", .{arg});
            std.debug.print("{s}", .{help_unpack});
            std.process.exit(1);
        } else if (file_path == null) {
            file_path = arg;
        } else {
            outdir_opt = arg;
        }
    }

    const path = file_path orelse {
        std.debug.print("romtool: unpack: no file specified\n", .{});
        std.debug.print("{s}", .{help_unpack});
        std.process.exit(1);
    };

    const cwd = std.Io.Dir.cwd();
    const data = cwd.readFileAlloc(io, path, alloc, .unlimited) catch |err| {
        std.debug.print("romtool: {s}: {s}\n", .{ path, @errorName(err) });
        std.process.exit(1);
    };
    defer alloc.free(data);

    // Determine format
    var fmt = detectFormat(path, data);
    if (format_override) |f| {
        if (std.mem.eql(u8, f, "nes")) {
            fmt = .nes;
        } else if (std.mem.eql(u8, f, "snes")) {
            fmt = .snes;
        } else {
            std.debug.print("romtool: --format: unknown '{s}' (use nes|snes)\n", .{f});
            std.process.exit(1);
        }
    }

    // Compute default outdir from stem
    const outdir: []const u8 = outdir_opt orelse blk: {
        const stem = std.fs.path.stem(path);
        break :blk try std.fmt.allocPrint(alloc, "{s}.unpack", .{stem});
    };
    defer if (outdir_opt == null) alloc.free(outdir);

    cwd.createDirPath(io, outdir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            std.debug.print("romtool: cannot create '{s}': {s}\n", .{ outdir, @errorName(err) });
            std.process.exit(1);
        },
    };

    var out_dir = cwd.openDir(io, outdir, .{}) catch |err| {
        std.debug.print("romtool: cannot open '{s}': {s}\n", .{ outdir, @errorName(err) });
        std.process.exit(1);
    };
    defer out_dir.close(io);

    switch (fmt) {
        .nes => try unpackNes(alloc, io, out_dir, path, data, outdir),
        .snes => try unpackSnes(alloc, io, out_dir, path, data, outdir),
        .raw => {
            std.debug.print("romtool: {s}: unknown format; use --format nes|snes to override\n", .{path});
            std.process.exit(1);
        },
    }
}

fn unpackNes(alloc: std.mem.Allocator, io: std.Io, out_dir: std.Io.Dir, path: []const u8, data: []const u8, outdir: []const u8) !void {
    if (data.len < 16 or !std.mem.eql(u8, data[0..4], "NES\x1a")) {
        std.debug.print("romtool: {s}: not a valid iNES file\n", .{path});
        std.process.exit(1);
    }

    const flags6 = data[6];
    const flags7 = data[7];
    const is_nes2 = (flags7 & 0x0C) == 0x08;
    const prg_banks: u32 = data[4];
    const chr_banks: u32 = data[5];
    const mapper_lo: u8 = (flags6 >> 4) & 0x0F;
    const mapper_hi: u8 = (flags7 >> 4) & 0x0F;
    const mapper: u16 = @as(u16, mapper_hi) << 4 | mapper_lo;
    const mirroring = if (flags6 & 0x08 != 0) "4-screen" else if (flags6 & 0x01 != 0) "vertical" else "horizontal";
    const battery = (flags6 & 0x02) != 0;

    // Write header.txt
    {
        const hdr_text = try std.fmt.allocPrint(alloc,
            \\format={s}
            \\mapper={d}
            \\prg_banks={d}
            \\prg_kb={d}
            \\chr_banks={d}
            \\chr_kb={d}
            \\mirroring={s}
            \\battery={s}
            \\
        , .{
            if (is_nes2) "NES 2.0" else "iNES 1.0",
            mapper,
            prg_banks,
            prg_banks * 16,
            chr_banks,
            chr_banks * 8,
            mirroring,
            if (battery) "yes" else "no",
        });
        defer alloc.free(hdr_text);
        try writeFile(io, out_dir, "header.txt", hdr_text);
    }

    const prg_size: usize = @as(usize, prg_banks) * 16384;
    const chr_size: usize = @as(usize, chr_banks) * 8192;

    const payload = data[16..];
    if (payload.len < prg_size) {
        std.debug.print("romtool: {s}: PRG data truncated\n", .{path});
        std.process.exit(1);
    }

    // Write PRG banks
    var b: usize = 0;
    while (b < prg_banks) : (b += 1) {
        const bank_data = payload[b * 16384 .. (b + 1) * 16384];
        const name = try std.fmt.allocPrint(alloc, "prg-bank-{x:0>2}.bin", .{b});
        defer alloc.free(name);
        try writeFile(io, out_dir, name, bank_data);
        std.debug.print("  wrote {s}/{s} ({d} bytes)\n", .{ outdir, name, bank_data.len });
    }

    // Write CHR banks
    if (chr_size > 0) {
        const chr_start = prg_size;
        if (payload.len < prg_size + chr_size) {
            std.debug.print("romtool: {s}: CHR data truncated\n", .{path});
        } else {
            var c: usize = 0;
            while (c < chr_banks) : (c += 1) {
                const chr_off = chr_start + c * 8192;
                const bank_data = payload[chr_off .. chr_off + 8192];
                const name = try std.fmt.allocPrint(alloc, "chr-bank-{x:0>2}.bin", .{c});
                defer alloc.free(name);
                try writeFile(io, out_dir, name, bank_data);
                std.debug.print("  wrote {s}/{s} ({d} bytes)\n", .{ outdir, name, bank_data.len });
            }
        }
    }

    std.debug.print("unpack: {s} → {s}/ ({d} PRG, {d} CHR banks)\n", .{ path, outdir, prg_banks, chr_banks });
}

fn unpackSnes(alloc: std.mem.Allocator, io: std.Io, out_dir: std.Io.Dir, path: []const u8, data: []const u8, outdir: []const u8) !void {
    // SMC files have a 512-byte copier header
    const has_smc = data.len % 1024 == 512;
    const rom_data = if (has_smc) data[512..] else data;

    // SNES header is at $7FC0 (LoROM) — read what we can
    var hdr_off: usize = 0x7FC0;
    var title_buf: [22]u8 = undefined;
    var title: []const u8 = "(unknown)";
    var map_mode: u8 = 0;
    var rom_size_byte: u8 = 0;
    var checksum: u16 = 0;
    var complement: u16 = 0;
    var reset_vec: u16 = 0;
    var nmi_vec: u16 = 0;

    // Auto-detect LoROM ($7FC0) vs HiROM ($FFC0) by checking map_mode byte.
    const valid_modes = [_]u8{ 0x20, 0x21, 0x23, 0x25, 0x30, 0x31 };
    const hirom_off: usize = 0xFFC0;
    if (rom_data.len >= hirom_off + 32) {
        const m = rom_data[hirom_off + 0x15];
        for (valid_modes) |v| {
            if (m == v) {
                hdr_off = hirom_off;
                break;
            }
        }
    }

    if (rom_data.len >= hdr_off + 0x30) {
        const h = rom_data[hdr_off..];
        const title_raw = h[0..21];
        var tlen: usize = 21;
        for (title_raw, 0..) |c, ti| {
            if (c == 0) {
                tlen = ti;
                break;
            }
            title_buf[ti] = if (c >= 0x20 and c < 0x7F) c else '.';
        }
        title = title_buf[0..tlen];
        map_mode = h[21];
        rom_size_byte = h[23];
        complement = readU16Le(h, 28);
        checksum = readU16Le(h, 30);
        const vec_base: usize = if (hdr_off == hirom_off) 0xFFFC else 0x7FFC;
        const nmi_base: usize = if (hdr_off == hirom_off) 0xFFEA else 0x7FEA;
        if (rom_data.len >= vec_base + 2)
            reset_vec = readU16Le(rom_data, vec_base);
        if (rom_data.len >= nmi_base + 2)
            nmi_vec = readU16Le(rom_data, nmi_base);
    }

    const checksum_ok = (checksum ^ complement) == 0xFFFF;

    const hdr_text = try std.fmt.allocPrint(alloc,
        \\title={s}
        \\map_mode=0x{x:0>2}
        \\rom_size_byte=0x{x:0>2}
        \\checksum=0x{x:0>4}
        \\complement=0x{x:0>4}
        \\checksum_ok={s}
        \\reset_vector=0x{x:0>4}
        \\nmi_vector=0x{x:0>4}
        \\smc_header={s}
        \\
    , .{
        title,
        map_mode,
        rom_size_byte,
        checksum,
        complement,
        if (checksum_ok) "yes" else "no",
        reset_vec,
        nmi_vec,
        if (has_smc) "yes" else "no",
    });
    defer alloc.free(hdr_text);
    try writeFile(io, out_dir, "header.txt", hdr_text);

    // Write 32KB banks (LoROM layout)
    const bank_size: usize = 32768;
    const num_banks = (rom_data.len + bank_size - 1) / bank_size;
    var b: usize = 0;
    while (b < num_banks) : (b += 1) {
        const start = b * bank_size;
        const end = @min(start + bank_size, rom_data.len);
        const bank_data = rom_data[start..end];
        const name = try std.fmt.allocPrint(alloc, "bank-{x:0>2}.bin", .{b});
        defer alloc.free(name);
        try writeFile(io, out_dir, name, bank_data);
        std.debug.print("  wrote {s}/{s} ({d} bytes)\n", .{ outdir, name, bank_data.len });
    }

    std.debug.print("unpack: {s} → {s}/ ({d} banks)\n", .{ path, outdir, num_banks });
}

fn writeFile(io: std.Io, dir: std.Io.Dir, name: []const u8, content: []const u8) !void {
    try dir.writeFile(io, .{ .sub_path = name, .data = content });
}

// ── pack command ──────────────────────────────────────────────────────────────

fn cmdPack(alloc: std.mem.Allocator, io: std.Io, args: anytype) !void {
    const sub = args.next() orelse {
        std.debug.print("romtool: pack: subcommand required (nes, snes)\n", .{});
        std.debug.print("{s}", .{help_pack});
        std.process.exit(1);
    };

    if (std.mem.eql(u8, sub, "nes")) {
        return cmdPackNes(alloc, io, args);
    } else if (std.mem.eql(u8, sub, "snes")) {
        return cmdPackSnes(alloc, io, args);
    } else {
        std.debug.print("romtool: pack: unknown subcommand '{s}' (use: nes, snes)\n", .{sub});
        std.debug.print("{s}", .{help_pack});
        std.process.exit(1);
    }
}

fn cmdPackNes(alloc: std.mem.Allocator, io: std.Io, args: anytype) !void {
    var mapper_num: u16 = 0;
    var mirror: u8 = 0; // 0=horizontal
    var battery = false;
    var emit_nes2 = false;
    var out_path: ?[]const u8 = null;
    var prg_path: ?[]const u8 = null;
    var chr_path: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--mapper")) {
            const val = args.next() orelse {
                std.debug.print("romtool: --mapper requires a value\n", .{});
                std.process.exit(1);
            };
            mapper_num = std.fmt.parseUnsigned(u16, val, 10) catch {
                std.debug.print("romtool: --mapper: invalid number '{s}'\n", .{val});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--mirror")) {
            const val = args.next() orelse {
                std.debug.print("romtool: --mirror requires a value\n", .{});
                std.process.exit(1);
            };
            if (std.mem.eql(u8, val, "v")) {
                mirror = 1;
            } else if (std.mem.eql(u8, val, "4")) {
                mirror = 2; // 4-screen flag
            } else if (!std.mem.eql(u8, val, "h")) {
                std.debug.print("romtool: --mirror: use h|v|4\n", .{});
                std.process.exit(1);
            }
        } else if (std.mem.eql(u8, arg, "--battery")) {
            battery = true;
        } else if (std.mem.eql(u8, arg, "--nes2")) {
            emit_nes2 = true;
        } else if (std.mem.eql(u8, arg, "-o")) {
            out_path = args.next() orelse {
                std.debug.print("romtool: -o requires a value\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("romtool: pack nes: unknown option '{s}'\n", .{arg});
            std.process.exit(1);
        } else if (prg_path == null) {
            prg_path = arg;
        } else if (chr_path == null) {
            chr_path = arg;
        }
    }

    const prg_file = prg_path orelse {
        std.debug.print("romtool: pack nes: no PRG file specified\n", .{});
        std.debug.print("{s}", .{help_pack});
        std.process.exit(1);
    };
    const out_file = out_path orelse {
        std.debug.print("romtool: pack nes: -o <out.nes> required\n", .{});
        std.process.exit(1);
    };

    const cwd = std.Io.Dir.cwd();

    const prg_data = cwd.readFileAlloc(io, prg_file, alloc, .unlimited) catch |err| {
        std.debug.print("romtool: {s}: {s}\n", .{ prg_file, @errorName(err) });
        std.process.exit(1);
    };
    defer alloc.free(prg_data);

    if (prg_data.len == 0 or prg_data.len % 16384 != 0) {
        std.debug.print("romtool: PRG size {d} is not a multiple of 16384\n", .{prg_data.len});
        std.process.exit(1);
    }

    var chr_data: []const u8 = &[_]u8{};
    var chr_alloc_buf: ?[]u8 = null;
    defer if (chr_alloc_buf) |b| alloc.free(b);

    if (chr_path) |cp| {
        const cd = cwd.readFileAlloc(io, cp, alloc, .unlimited) catch |err| {
            std.debug.print("romtool: {s}: {s}\n", .{ cp, @errorName(err) });
            std.process.exit(1);
        };
        chr_alloc_buf = cd;
        chr_data = cd;
        if (chr_data.len % 8192 != 0) {
            std.debug.print("romtool: CHR size {d} is not a multiple of 8192\n", .{chr_data.len});
            std.process.exit(1);
        }
    }

    const prg_banks: u8 = @intCast(prg_data.len / 16384);
    const chr_banks: u8 = @intCast(chr_data.len / 8192);

    // Build flags6/flags7
    var flags6: u8 = 0;
    if (mirror == 1) flags6 |= 0x01; // vertical
    if (battery) flags6 |= 0x02;
    if (mirror == 2) flags6 |= 0x08; // 4-screen
    flags6 |= @as(u8, @truncate(mapper_num & 0x0F)) << 4;

    var flags7: u8 = 0;
    flags7 |= @as(u8, @truncate((mapper_num >> 4) & 0x0F)) << 4;
    if (emit_nes2) flags7 |= 0x08;

    var header = [_]u8{0} ** 16;
    header[0] = 'N';
    header[1] = 'E';
    header[2] = 'S';
    header[3] = 0x1A;
    header[4] = prg_banks;
    header[5] = chr_banks;
    header[6] = flags6;
    header[7] = flags7;

    var out_f = cwd.createFile(io, out_file, .{ .truncate = true }) catch |err| {
        std.debug.print("romtool: {s}: {s}\n", .{ out_file, @errorName(err) });
        std.process.exit(1);
    };
    defer out_f.close(io);

    try out_f.writeStreamingAll(io, &header);
    try out_f.writeStreamingAll(io, prg_data);
    if (chr_data.len > 0) try out_f.writeStreamingAll(io, chr_data);

    std.debug.print("pack: wrote {s}  mapper={d}  PRG={d}KB  CHR={d}KB\n", .{
        out_file, mapper_num, @as(usize, prg_banks) * 16, @as(usize, chr_banks) * 8,
    });
}

fn nextPow2(n: usize) usize {
    if (n == 0) return 1;
    var p: usize = 1;
    while (p < n) p <<= 1;
    return p;
}

fn cmdPackSnes(alloc: std.mem.Allocator, io: std.Io, args: anytype) !void {
    var out_path: ?[]const u8 = null;
    var map_opt: ?[]const u8 = null;
    var title_opt: ?[]const u8 = null;
    var add_smc = false;
    var bank_paths: std.ArrayListUnmanaged([]const u8) = .empty;
    defer bank_paths.deinit(alloc);

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-o")) {
            out_path = args.next() orelse {
                std.debug.print("romtool: -o requires a value\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--map")) {
            map_opt = args.next() orelse {
                std.debug.print("romtool: --map requires a value\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--title")) {
            title_opt = args.next() orelse {
                std.debug.print("romtool: --title requires a value\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--smc")) {
            add_smc = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("romtool: pack snes: unknown option '{s}'\n", .{arg});
            std.debug.print("{s}", .{help_pack});
            std.process.exit(1);
        } else {
            try bank_paths.append(alloc, arg);
        }
    }

    if (bank_paths.items.len == 0) {
        std.debug.print("romtool: pack snes: no input files specified\n", .{});
        std.debug.print("{s}", .{help_pack});
        std.process.exit(1);
    }
    const out_file = out_path orelse {
        std.debug.print("romtool: pack snes: -o <out.sfc> required\n", .{});
        std.process.exit(1);
    };

    const cwd = std.Io.Dir.cwd();

    // Read and concatenate all bank files
    var rom_buf: std.ArrayListUnmanaged(u8) = .empty;
    defer rom_buf.deinit(alloc);
    for (bank_paths.items) |bp| {
        const bdata = cwd.readFileAlloc(io, bp, alloc, .unlimited) catch |err| {
            std.debug.print("romtool: {s}: {s}\n", .{ bp, @errorName(err) });
            std.process.exit(1);
        };
        defer alloc.free(bdata);
        try rom_buf.appendSlice(alloc, bdata);
    }

    if (rom_buf.items.len < 32768) {
        std.debug.print("romtool: pack snes: ROM too small ({d}B, minimum 32KB)\n", .{rom_buf.items.len});
        std.process.exit(1);
    }

    // Pad to next power of 2
    const padded_size = nextPow2(rom_buf.items.len);
    while (rom_buf.items.len < padded_size) {
        try rom_buf.append(alloc, 0xFF);
    }
    const rom = rom_buf.items;

    // Determine map mode byte
    const valid_modes = [_]u8{ 0x20, 0x21, 0x23, 0x25, 0x30, 0x31 };
    const map_byte: u8 = if (map_opt) |m| blk: {
        if (std.mem.eql(u8, m, "lorom")) break :blk 0x20;
        if (std.mem.eql(u8, m, "fastrom")) break :blk 0x30;
        if (std.mem.eql(u8, m, "hirom")) break :blk 0x21;
        std.debug.print("romtool: --map: use lorom|fastrom|hirom\n", .{});
        std.process.exit(1);
    } else blk: {
        // Auto-detect: try HiROM offset first, then LoROM
        const hirom_off: usize = 0xFFC0;
        if (rom.len >= hirom_off + 32) {
            const m = rom[hirom_off + 0x15];
            for (valid_modes) |v| if (m == v) break :blk m;
        }
        if (rom.len >= 0x7FC0 + 32) {
            const m = rom[0x7FC0 + 0x15];
            for (valid_modes) |v| if (m == v) break :blk m;
        }
        break :blk @as(u8, 0x20); // default LoROM
    };

    const is_hirom = (map_byte & 0x01) != 0;
    const hdr_off: usize = if (is_hirom and rom.len >= 0xFFC0 + 32) 0xFFC0 else 0x7FC0;

    if (rom.len < hdr_off + 32) {
        std.debug.print("romtool: pack snes: ROM too small for header at ${x:0>4}\n", .{hdr_off});
        std.process.exit(1);
    }

    // Write map mode
    rom[hdr_off + 0x15] = map_byte;

    // Write ROM size byte (log2(size_bytes) - 10)
    const log2_size: usize = @ctz(padded_size);
    rom[hdr_off + 0x17] = @intCast(log2_size - 10);

    // Write title if provided
    if (title_opt) |t| {
        var title_bytes = [_]u8{0x20} ** 21;
        const copy_len = @min(t.len, 21);
        @memcpy(title_bytes[0..copy_len], t[0..copy_len]);
        @memcpy(rom[hdr_off..][0..21], &title_bytes);
    }

    // Compute SNES checksum: zero the 4 header bytes, sum all, then fill
    const chk_off = hdr_off + 28; // complement at +28, checksum at +30
    rom[chk_off + 0] = 0x00;
    rom[chk_off + 1] = 0x00;
    rom[chk_off + 2] = 0x00;
    rom[chk_off + 3] = 0x00;

    var sum: u32 = 0;
    for (rom) |b| sum += b;
    const checksum: u16 = @truncate(sum);
    const complement: u16 = checksum ^ 0xFFFF;

    rom[chk_off + 0] = @truncate(complement);
    rom[chk_off + 1] = @truncate(complement >> 8);
    rom[chk_off + 2] = @truncate(checksum);
    rom[chk_off + 3] = @truncate(checksum >> 8);

    // Write output
    var out_f = cwd.createFile(io, out_file, .{ .truncate = true }) catch |err| {
        std.debug.print("romtool: {s}: {s}\n", .{ out_file, @errorName(err) });
        std.process.exit(1);
    };
    defer out_f.close(io);

    if (add_smc) {
        const smc_hdr = [_]u8{0x00} ** 512;
        try out_f.writeStreamingAll(io, &smc_hdr);
    }
    try out_f.writeStreamingAll(io, rom);

    const map_name = switch (map_byte) {
        0x20 => "LoROM",
        0x21 => "HiROM",
        0x30 => "FastROM",
        0x31 => "HiROM/Fast",
        else => "custom",
    };
    std.debug.print("pack: wrote {s}  {s}  {d}KB  chk=0x{x:0>4}  cpl=0x{x:0>4}{s}\n", .{
        out_file,
        map_name,
        padded_size / 1024,
        checksum,
        complement,
        if (add_smc) "  +SMC" else "",
    });
}

// ── entry point ───────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    var args = try init.minimal.args.iterateAllocator(alloc);
    defer args.deinit();
    _ = args.next(); // skip argv[0]

    const cmd = args.next() orelse helpExit();
    if (std.mem.eql(u8, cmd, "help")) helpCmd(&args);
    if (std.mem.eql(u8, cmd, "disasm")) return cmdDisasm(alloc, io, &args);
    if (std.mem.eql(u8, cmd, "unpack")) return cmdUnpack(alloc, io, &args);
    if (std.mem.eql(u8, cmd, "pack")) return cmdPack(alloc, io, &args);
    std.debug.print("romtool: unknown command '{s}'\n", .{cmd});
    std.debug.print("{s}", .{help_main});
    std.process.exit(1);
}
