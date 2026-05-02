// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! bininfo — multi-format binary inspector for mos-examples output files.
//!
//! Usage: bininfo <file> [file...]
//!
//! Detected formats (by magic bytes, then file extension):
//!   .nes  — NES iNES / NES 2.0 ROM
//!   .prg  — Commodore 64 / CX16 / MEGA65 program file
//!   .a26  — Atari 2600 cartridge ROM (2K–32K)
//!   .xex  — Atari 8-bit DOS executable
//!   .neo  — Neo6502 load file
//!   .pce  — PC Engine cartridge ROM (raw, multiples of 8KB)
//!   .bll  — Atari Lynx Binary Load Library
//!   .rom  — Atari 8-bit standard cartridge ROM
//!   .sys  — Apple IIe ProDOS SYS file (raw binary, load=$0800)
//!   sim   — mos-sim binary (load=$0200 header + data + vectors trailer)
//!
//! Exit code: 0 if all files are valid, 1 if any file is missing or malformed.

const std = @import("std");

// ── helpers ──────────────────────────────────────────────────────────────────

fn readU16Le(data: []const u8, off: usize) u16 {
    return @as(u16, data[off]) | (@as(u16, data[off + 1]) << 8);
}

fn readU32Le(data: []const u8, off: usize) u32 {
    return @as(u32, data[off]) |
        (@as(u32, data[off + 1]) << 8) |
        (@as(u32, data[off + 2]) << 16) |
        (@as(u32, data[off + 3]) << 24);
}

// ── ELF constants ─────────────────────────────────────────────────────────────

const SHT_NULL: u32 = 0;
const SHT_SYMTAB: u32 = 2;
const SHT_STRTAB: u32 = 3;
const SHT_NOBITS: u32 = 8;
const SHT_DYNSYM: u32 = 11;

const SHF_WRITE: u32 = 0x1;
const SHF_ALLOC: u32 = 0x2;
const SHF_EXECINSTR: u32 = 0x4;
const SHF_MERGE: u32 = 0x10;
const SHF_STRINGS: u32 = 0x20;
const SHF_LINK_ORDER: u32 = 0x80;
const SHF_GROUP: u32 = 0x200;
const SHF_TLS: u32 = 0x400;

const SHN_UNDEF: u16 = 0;
const SHN_ABS: u16 = 0xFFF1;
const SHN_COMMON: u16 = 0xFFF2;

const STB_LOCAL: u8 = 0;
const STB_GLOBAL: u8 = 1;
const STB_WEAK: u8 = 2;

fn elfMachName(m: u16) []const u8 {
    return switch (m) {
        0x1966 => "MOS6502", // EM_MOS (llvm-mos)
        3 => "x86",
        0x3E => "x86-64",
        0xB7 => "AArch64",
        0x28 => "ARM",
        else => "?",
    };
}

fn elfTypeName(t: u16) []const u8 {
    return switch (t) {
        0 => "NONE",
        1 => "REL",
        2 => "EXEC",
        3 => "DYN",
        4 => "CORE",
        else => "?",
    };
}

// nm-style type character derived from section attributes and symbol binding.
fn nmTypeChar(sh_type: u32, sh_flags: u32, shndx: u16, binding: u8) u8 {
    const is_local = binding == STB_LOCAL;
    const is_weak = binding == STB_WEAK;
    if (shndx == SHN_UNDEF) return if (is_weak) 'w' else 'U';
    if (shndx == SHN_ABS) return if (is_local) 'a' else 'A';
    if (shndx == SHN_COMMON) return 'C';
    const c: u8 = if (sh_type == SHT_NOBITS and (sh_flags & SHF_ALLOC) != 0)
        'b' // BSS
    else if ((sh_flags & SHF_EXECINSTR) != 0)
        't' // text
    else if ((sh_flags & SHF_WRITE) != 0)
        'd' // data
    else
        'r'; // read-only
    if (is_weak) return if (c == 't') 'W' else 'V';
    return if (!is_local) std.ascii.toUpper(c) else c;
}

// ── ELF inspector ─────────────────────────────────────────────────────────────

fn checkElf(path: []const u8, data: []const u8) bool {
    if (data.len < 52) {
        std.debug.print("{s}: [ELF] ERROR: header truncated ({d} B)\n", .{ path, data.len });
        return false;
    }
    const ei_class = data[4]; // 1=32-bit, 2=64-bit
    const ei_data = data[5]; // 1=LE, 2=BE
    if (ei_data != 1) {
        std.debug.print("{s}: [ELF] big-endian ELF not supported by bininfo\n", .{path});
        return true;
    }
    if (ei_class != 1) {
        std.debug.print("{s}: [ELF64]  (64-bit ELF; summary only)\n", .{path});
        return true;
    }

    const e_type = readU16Le(data, 16);
    const e_machine = readU16Le(data, 18);
    const e_entry = readU32Le(data, 24);
    const e_shoff = readU32Le(data, 32);
    const e_shentsize = readU16Le(data, 46);
    const e_shnum = readU16Le(data, 48);
    const e_shstrndx = readU16Le(data, 50);

    if (e_shoff == 0 or e_shentsize < 40 or
        @as(usize, e_shoff) + @as(usize, e_shnum) * e_shentsize > data.len)
    {
        std.debug.print("{s}: [ELF32 {s}]  type={s}  entry=${x:0>4}  (no section table)\n", .{
            path, elfMachName(e_machine), elfTypeName(e_type), e_entry,
        });
        return true;
    }

    // Build a helper: return a slice of a section header's bytes.
    const shdr = struct {
        fn get(d: []const u8, shoff: u32, shentsz: u16, idx: u16) []const u8 {
            const off: usize = shoff + @as(usize, idx) * shentsz;
            return d[off .. off + shentsz];
        }
    };

    // Locate shstrtab for section name lookup.
    const shstr_hdr = shdr.get(data, e_shoff, e_shentsize, e_shstrndx);
    const shstr_off = readU32Le(shstr_hdr, 16);
    const shstr_size = readU32Le(shstr_hdr, 20);
    const shstr: []const u8 = if (shstr_off + shstr_size <= data.len)
        data[shstr_off .. shstr_off + shstr_size]
    else
        &[_]u8{};

    // Count allocatable sections (for the summary).
    var alloc_count: u16 = 0;
    for (0..e_shnum) |i| {
        const sh = shdr.get(data, e_shoff, e_shentsize, @truncate(i));
        if ((readU32Le(sh, 8) & SHF_ALLOC) != 0) alloc_count += 1;
    }

    // Find .symtab; fall back to .dynsym for stripped binaries.
    var symtab_off: usize = 0;
    var symtab_size: usize = 0;
    var symtab_stridx: u32 = 0;
    var sym_local_end: u32 = 0;
    var found_symtab = false;
    for (0..e_shnum) |i| {
        const sh = shdr.get(data, e_shoff, e_shentsize, @truncate(i));
        const sht = readU32Le(sh, 4);
        if (sht == SHT_SYMTAB or (sht == SHT_DYNSYM and !found_symtab)) {
            symtab_off = readU32Le(sh, 16);
            symtab_size = readU32Le(sh, 20);
            symtab_stridx = readU32Le(sh, 24);
            sym_local_end = readU32Le(sh, 28); // sh_info = one past last LOCAL
            if (sht == SHT_SYMTAB) {
                found_symtab = true;
                break;
            }
        }
    }

    // Locate symbol string table.
    var strtab_data: []const u8 = &[_]u8{};
    if (symtab_stridx < e_shnum) {
        const sh = shdr.get(data, e_shoff, e_shentsize, @truncate(symtab_stridx));
        const st_off = readU32Le(sh, 16);
        const st_sz = readU32Le(sh, 20);
        if (st_off + st_sz <= data.len)
            strtab_data = data[st_off .. st_off + st_sz];
    }

    const sym_count = if (symtab_size >= 16) symtab_size / 16 else 0;

    std.debug.print("{s}: [ELF32 {s}]  type={s}  entry=${x:0>4}  alloc-sections={d}  symbols={d}\n", .{
        path, elfMachName(e_machine), elfTypeName(e_type), e_entry, alloc_count, sym_count,
    });

    // ── Section table (ALLOC sections only, like objdump -h) ─────────────────
    std.debug.print("  -- Sections " ++ "-" ** 42 ++ "\n", .{});
    std.debug.print("  {s:<20} {s:>8}  {s:>8}  {s}\n", .{ "Name", "Size", "VMA", "Flags" });
    for (0..e_shnum) |i| {
        const sh = shdr.get(data, e_shoff, e_shentsize, @truncate(i));
        const sh_flags = readU32Le(sh, 8);
        if ((sh_flags & SHF_ALLOC) == 0) continue;
        const sh_name_off = readU32Le(sh, 0);
        const sh_addr = readU32Le(sh, 12);
        const sh_size = readU32Le(sh, 20);
        const sh_type = readU32Le(sh, 4);

        // Read section name from shstrtab.
        const name: []const u8 = if (sh_name_off < shstr.len) blk: {
            const start = sh_name_off;
            var end = start;
            while (end < shstr.len and shstr[end] != 0) end += 1;
            break :blk shstr[start..end];
        } else "?";

        // Build compact readelf-style flag string: AX, AW, AWl, etc.
        var fbuf: [12]u8 = undefined;
        var flen: usize = 0;
        fbuf[flen] = 'A';
        flen += 1; // always ALLOC (we skip non-ALLOC above)
        if ((sh_flags & SHF_EXECINSTR) != 0) {
            fbuf[flen] = 'X';
            flen += 1;
        }
        if ((sh_flags & SHF_WRITE) != 0) {
            fbuf[flen] = 'W';
            flen += 1;
        }
        if (sh_type == SHT_NOBITS) {
            fbuf[flen] = 'B';
            flen += 1;
        }
        if ((sh_flags & SHF_MERGE) != 0) {
            fbuf[flen] = 'M';
            flen += 1;
        }
        if ((sh_flags & SHF_STRINGS) != 0) {
            fbuf[flen] = 'S';
            flen += 1;
        }
        if ((sh_flags & SHF_TLS) != 0) {
            fbuf[flen] = 'T';
            flen += 1;
        }
        if ((sh_flags & SHF_GROUP) != 0) {
            fbuf[flen] = 'G';
            flen += 1;
        }
        if ((sh_flags & SHF_LINK_ORDER) != 0) {
            fbuf[flen] = 'l';
            flen += 1;
        }

        std.debug.print("  {s:<20} {d:>8}B  ${x:0>4}  {s}\n", .{
            name, sh_size, sh_addr, fbuf[0..flen],
        });
    }

    // ── Symbol table (like nm, global + weak only unless very few symbols) ───
    if (sym_count == 0 or symtab_off + symtab_size > data.len) return true;

    // Build a per-symbol section cache for type resolution.
    // For each symbol we need its section's sh_type and sh_flags.
    std.debug.print("  -- Symbols (nm) " ++ "-" ** 38 ++ "\n", .{});

    const sym_base = symtab_off;
    const show_locals = sym_count < 64; // show locals only for small objects
    var printed: usize = 0;

    for (0..sym_count) |si| {
        const sym = data[sym_base + si * 16 .. sym_base + si * 16 + 16];
        const st_name = readU32Le(sym, 0);
        const st_value = readU32Le(sym, 4);
        const st_info = sym[12];
        const st_shndx: u16 = readU16Le(sym, 14);
        const binding: u8 = st_info >> 4;
        const stype: u8 = st_info & 0xF;

        // Skip FILE/SECTION symbols and empty names.
        if (stype == 3 or stype == 4) continue;
        if (!show_locals and binding == STB_LOCAL) continue;

        const name: []const u8 = if (st_name < strtab_data.len) blk: {
            var end = st_name;
            while (end < strtab_data.len and strtab_data[end] != 0) end += 1;
            if (end == st_name) continue; // empty name
            break :blk strtab_data[st_name..end];
        } else continue;

        // Look up the section's type and flags for this symbol.
        var sh_type_for_sym: u32 = 0;
        var sh_flags_for_sym: u32 = 0;
        if (st_shndx != SHN_UNDEF and st_shndx != SHN_ABS and st_shndx != SHN_COMMON and
            st_shndx < e_shnum)
        {
            const sym_sh = shdr.get(data, e_shoff, e_shentsize, st_shndx);
            sh_type_for_sym = readU32Le(sym_sh, 4);
            sh_flags_for_sym = readU32Le(sym_sh, 8);
        }

        const tc = nmTypeChar(sh_type_for_sym, sh_flags_for_sym, st_shndx, binding);
        std.debug.print("  ${x:0>4} {c}  {s}\n", .{ st_value, tc, name });
        printed += 1;
    }
    if (printed == 0)
        std.debug.print("  (no symbols — binary may be stripped)\n", .{});

    // ── MOS DWARF inventory ───────────────────────────────────────────────
    if (e_machine == 0x1966) {
        const dwarf_names = [_][]const u8{
            ".debug_info",
            ".debug_abbrev",
            ".debug_line",
            ".debug_str",
            ".debug_ranges",
            ".debug_loc",
            ".debug_aranges",
            ".debug_frame",
            ".eh_frame",
        };
        var dwarf_offsets = [_]u32{0} ** dwarf_names.len;
        var dwarf_sizes = [_]u32{0} ** dwarf_names.len;

        for (0..e_shnum) |i| {
            const sh = shdr.get(data, e_shoff, e_shentsize, @truncate(i));
            if ((readU32Le(sh, 8) & SHF_ALLOC) != 0) continue; // DWARF is non-ALLOC
            const name_off = readU32Le(sh, 0);
            if (name_off >= shstr.len) continue;
            var name_end = name_off;
            while (name_end < shstr.len and shstr[name_end] != 0) name_end += 1;
            const sec_name = shstr[name_off..name_end];
            for (dwarf_names, 0..) |dn, di| {
                if (std.mem.eql(u8, sec_name, dn)) {
                    dwarf_offsets[di] = readU32Le(sh, 16);
                    dwarf_sizes[di] = readU32Le(sh, 20);
                    break;
                }
            }
        }

        var any_dwarf = false;
        for (dwarf_sizes) |sz| {
            if (sz > 0) {
                any_dwarf = true;
                break;
            }
        }

        if (any_dwarf) {
            // Parse .debug_info CU headers: version (bytes 4-5 of each CU header) + unit count.
            var dwarf_ver: u16 = 0;
            var cu_count: u32 = 0;
            const di_off = dwarf_offsets[0];
            const di_sz = dwarf_sizes[0];
            if (di_sz >= 6 and di_off + di_sz <= data.len) {
                dwarf_ver = readU16Le(data, di_off + 4);
                var pos: usize = di_off;
                const di_end: usize = di_off + di_sz;
                while (pos + 4 <= di_end) {
                    const unit_len = readU32Le(data, pos);
                    if (unit_len == 0 or pos + 4 + unit_len > di_end) break;
                    cu_count += 1;
                    pos += 4 + unit_len;
                }
            }

            std.debug.print("  -- DWARF " ++ "-" ** 45 ++ "\n", .{});
            if (dwarf_ver > 0)
                std.debug.print("  version=DWARFv{d}  compile-units={d}\n", .{ dwarf_ver, cu_count });

            for (dwarf_names, 0..) |dn, di| {
                const sz = dwarf_sizes[di];
                if (sz > 0) {
                    std.debug.print("  {s:<20} {d:>8}B\n", .{ dn, sz });
                } else if (std.mem.eql(u8, dn, ".debug_frame")) {
                    std.debug.print("  {s:<20}  (absent — no CFI; stack unwinding not supported on MOS)\n", .{dn});
                }
            }
        }
    }

    return true;
}

fn usageExit() noreturn {
    std.debug.print("Usage: bininfo <file> [file...]\n", .{});
    std.process.exit(1);
}

// ── format parsers ────────────────────────────────────────────────────────────

fn checkNes(path: []const u8, data: []const u8) bool {
    if (data.len < 16) {
        std.debug.print("{s}: [NES] ERROR: file too small ({d} B)\n", .{ path, data.len });
        return false;
    }
    // Detect NES 2.0: byte 7 bits 2-3 == 0b10
    const flags7 = data[7];
    const is_nes2 = (flags7 & 0x0C) == 0x08;

    const prg_16k: u32 = data[4];
    const chr_8k: u32 = data[5];
    const flags6 = data[6];
    const mapper_lo: u8 = (flags6 >> 4) & 0x0F;
    const mapper_hi: u8 = (flags7 >> 4) & 0x0F;
    const mapper: u16 = @as(u16, mapper_hi) << 4 | mapper_lo;
    const mirroring = if (flags6 & 0x08 != 0) "4-screen" else if (flags6 & 0x01 != 0) "vertical" else "horizontal";
    const battery = (flags6 & 0x02) != 0;

    const prg_kb = prg_16k * 16;
    const chr_kb = chr_8k * 8;
    const payload = data.len - 16;

    std.debug.print("{s}: [{s}]  mapper={d}  PRG={d}KB  CHR={d}KB  " ++
        "mirror={s}  battery={s}  payload={d}B\n", .{
        path,
        if (is_nes2) "NES 2.0" else "iNES 1.0",
        mapper,
        prg_kb,
        chr_kb,
        mirroring,
        if (battery) "yes" else "no",
        payload,
    });
    return true;
}

fn checkPrg(path: []const u8, data: []const u8) bool {
    if (data.len < 3) {
        std.debug.print("{s}: [PRG] ERROR: file too small ({d} B)\n", .{ path, data.len });
        return false;
    }
    const load = readU16Le(data, 0);
    const size: u16 = @truncate(data.len - 2);
    const end = load +% size -% 1;
    std.debug.print("{s}: [CBM PRG]  load=${x:0>4}  size={d}B  end=${x:0>4}\n", .{
        path, load, size, end,
    });
    return true;
}

fn checkA26(path: []const u8, data: []const u8) bool {
    const len = data.len;
    if (len != 2048 and len != 4096 and len != 8192 and len != 16384 and len != 32768) {
        std.debug.print("{s}: [A26] ERROR: unexpected ROM size {d}B (expected 2K/4K/8K/16K/32K)\n", .{
            path, len,
        });
        return false;
    }
    // 6502 vectors are at the end of the address space mapped by the ROM.
    // For any cart size: last 6 bytes = NMI(2) + RESET(2) + IRQ(2).
    const nmi = readU16Le(data, len - 6);
    const reset = readU16Le(data, len - 4);
    const irq = readU16Le(data, len - 2);
    std.debug.print("{s}: [Atari 2600]  size={d}KB  NMI=${x:0>4}  RESET=${x:0>4}  IRQ=${x:0>4}\n", .{
        path, len / 1024, nmi, reset, irq,
    });
    return true;
}

fn checkXex(path: []const u8, data: []const u8) bool {
    if (data.len < 6 or readU16Le(data, 0) != 0xFFFF) {
        std.debug.print("{s}: [XEX] ERROR: missing 0xFFFF magic\n", .{path});
        return false;
    }
    var run_addr: ?u16 = null;
    var seg_count: u32 = 0;
    var pos: usize = 2;
    var ok = true;
    while (pos + 4 <= data.len) {
        const start = readU16Le(data, pos);
        const end = readU16Le(data, pos + 2);
        pos += 4;
        if (start == 0xFFFF) continue; // extra magic between segments
        if (end < start) {
            std.debug.print("{s}: [XEX] ERROR: segment end ${x:0>4} < start ${x:0>4}\n", .{ path, end, start });
            ok = false;
            break;
        }
        const seg_len: usize = @as(usize, end) - start + 1;
        if (pos + seg_len > data.len) {
            std.debug.print("{s}: [XEX] ERROR: segment data truncated\n", .{path});
            ok = false;
            break;
        }
        if (start == 0x02E0 and end == 0x02E1) {
            run_addr = readU16Le(data, pos);
        }
        seg_count += 1;
        pos += seg_len;
    }
    if (!ok) return false;
    if (run_addr) |ra| {
        std.debug.print("{s}: [Atari XEX]  segments={d}  run=${x:0>4}  size={d}B\n", .{
            path, seg_count, ra, data.len,
        });
    } else {
        std.debug.print("{s}: [Atari XEX]  segments={d}  run=(none)  size={d}B\n", .{
            path, seg_count, data.len,
        });
    }
    return true;
}

fn checkNeo(path: []const u8, data: []const u8) bool {
    // .neo header: 03 'N' 'E' 'O' maj min exec_lo exec_hi ctrl load_lo load_hi sz_lo sz_hi nul
    if (data.len < 14 or
        data[0] != 0x03 or data[1] != 'N' or data[2] != 'E' or data[3] != 'O')
    {
        std.debug.print("{s}: [NEO] ERROR: invalid magic\n", .{path});
        return false;
    }
    const ver_maj = data[4];
    const ver_min = data[5];
    const exec = readU16Le(data, 6);
    const load = readU16Le(data, 9);
    const size = readU16Le(data, 11);
    std.debug.print("{s}: [Neo6502]  ver={d}.{d}  exec=${x:0>4}  load=${x:0>4}  payload={d}B\n", .{
        path, ver_maj, ver_min, exec, load, size,
    });
    return true;
}

fn checkSfc(path: []const u8, data: []const u8) bool {
    const len = data.len;
    if (len < 32768 or (len % 32768) != 0) {
        std.debug.print("{s}: [SFC] ERROR: unexpected size {d}B (expected multiple of 32KB)\n", .{ path, len });
        return false;
    }
    // LoROM internal header sits at $7FC0 within the first 32KB bank.
    const hdr: usize = 0x7FC0;
    const map_mode = data[hdr + 0x15]; // $7FD5: $20=LoROM/Slow, $30=LoROM/Fast, $21=HiROM, $31=HiROM/Fast
    const rom_sz_byte = data[hdr + 0x17]; // $7FD7: 1KB << n
    const chksum = readU16Le(data, hdr + 0x1E); // $7FDE
    const chksum_comp = readU16Le(data, hdr + 0x1C); // $7FDC
    const chk_ok = (chksum +% chksum_comp) == 0xFFFF;

    // Title: 21 ASCII bytes at $7FC0, space-padded — trim trailing spaces.
    var title: [21]u8 = data[hdr..][0..21].*;
    var tlen: usize = 21;
    while (tlen > 0 and title[tlen - 1] == ' ') tlen -= 1;

    const map_name: []const u8 = switch (map_mode & 0x37) {
        0x20 => "LoROM",
        0x21 => "HiROM",
        0x23 => "SA-1",
        0x25 => "ExHiROM",
        0x30 => "LoROM/Fast",
        0x31 => "HiROM/Fast",
        else => "unknown",
    };

    // Emulation-mode RESET vector: CPU $FFFC = file offset $7FFC (LoROM).
    const reset = readU16Le(data, 0x7FFC);
    // Native-mode NMI vector: CPU $FFEA = file offset $7FEA (LoROM).
    const nmi_native = readU16Le(data, 0x7FEA);
    const rom_kb: u32 = if (rom_sz_byte < 14) @as(u32, 1) << @truncate(rom_sz_byte) else 0;

    std.debug.print(
        "{s}: [SNES {s}]  size={d}KB  title=\"{s}\"  map=${x:0>2}  RESET=${x:0>4}  NMI(native)=${x:0>4}  rom={d}KB  chk={s}\n",
        .{ path, map_name, len / 1024, title[0..tlen], map_mode, reset, nmi_native, rom_kb, if (chk_ok) "ok" else "BAD" },
    );
    return true;
}

fn checkPce(path: []const u8, data: []const u8) bool {
    const len = data.len;
    if (len == 0 or (len % 8192) != 0) {
        std.debug.print("{s}: [PCE] ERROR: unexpected size {d}B (expected multiple of 8KB)\n", .{ path, len });
        return false;
    }
    // RESET vector is at the last 2 bytes of the fixed bank (0xFFFE in addr space).
    const reset = readU16Le(data, len - 2);
    std.debug.print("{s}: [PC Engine]  size={d}KB  reset=${x:0>4}\n", .{
        path, len / 1024, reset,
    });
    return true;
}

fn checkBll(path: []const u8, data: []const u8) bool {
    // Lynx BLL header: SHORT(0x0880)=0x80,0x08  BYTE hi_load BYTE lo_load  BYTE hi_len BYTE lo_len  "BS93"
    if (data.len < 10 or data[0] != 0x80 or data[1] != 0x08) {
        std.debug.print("{s}: [BLL] ERROR: invalid BLL magic\n", .{path});
        return false;
    }
    const load: u16 = (@as(u16, data[2]) << 8) | data[3]; // big-endian
    const total: u16 = (@as(u16, data[4]) << 8) | data[5]; // big-endian
    const data_size: u16 = if (total >= 10) total - 10 else 0;
    std.debug.print("{s}: [Lynx BLL]  load=${x:0>4}  data={d}B  total={d}B\n", .{
        path, load, data_size, total,
    });
    return true;
}

fn checkSys(path: []const u8, data: []const u8) bool {
    // ProDOS SYS file: raw 6502 binary, load address $0800, no file header.
    if (data.len == 0) {
        std.debug.print("{s}: [Apple IIe SYS] ERROR: empty file\n", .{path});
        return false;
    }
    const load: u16 = 0x0800;
    const end: u16 = load +% @as(u16, @truncate(data.len)) -% 1;
    std.debug.print("{s}: [Apple IIe ProDOS SYS]  load=${x:0>4}  size={d}B  end=${x:0>4}\n", .{
        path, load, data.len, end,
    });
    return true;
}

fn checkSim(path: []const u8, data: []const u8) bool {
    // sim OUTPUT_FORMAT: SHORT($0200) SHORT(data_len) TRIM(ram)
    //   followed by: SHORT($FFFA) SHORT(6) SHORT(nmi) SHORT(reset) SHORT(irq)
    if (data.len < 14) {
        std.debug.print("{s}: [mos-sim] ERROR: file too small ({d} B)\n", .{ path, data.len });
        return false;
    }
    const data_len = readU16Le(data, 2);
    if (@as(usize, data_len) + 14 != data.len) {
        std.debug.print("{s}: [mos-sim] ERROR: size mismatch (header says {d}B data, file={d}B)\n", .{
            path, data_len, data.len,
        });
        return false;
    }
    const vbase = data.len - 10;
    const nmi = readU16Le(data, vbase + 4);
    const reset = readU16Le(data, vbase + 6);
    const irq = readU16Le(data, vbase + 8);
    std.debug.print("{s}: [mos-sim]  load=$0200  code={d}B  NMI=${x:0>4}  RESET=${x:0>4}  IRQ=${x:0>4}\n", .{
        path, data_len, nmi, reset, irq,
    });
    return true;
}

fn checkAtari8Cart(path: []const u8, data: []const u8) bool {
    const len = data.len;
    if (len != 8192 and len != 16384 and len != 32768 and len != 65536) {
        std.debug.print("{s}: [A8CART] ERROR: unexpected size {d}B (expected 8K/16K/32K/64K)\n", .{ path, len });
        return false;
    }
    // Run address at 0xBFFE–0xBFFF (little-endian) = last 2 bytes for 8KB ROM at 0xA000.
    const run = readU16Le(data, len - 2);
    std.debug.print("{s}: [Atari 8-bit cart]  size={d}KB  run=${x:0>4}\n", .{
        path, len / 1024, run,
    });
    return true;
}

// ── dispatch ──────────────────────────────────────────────────────────────────

fn checkFile(path: []const u8, data: []const u8) bool {
    // Detect by magic first.
    if (data.len >= 4 and std.mem.eql(u8, data[0..4], "\x7FELF"))
        return checkElf(path, data);
    if (data.len >= 4 and std.mem.eql(u8, data[0..4], "NES\x1a"))
        return checkNes(path, data);
    if (data.len >= 4 and data[0] == 0x03 and std.mem.eql(u8, data[1..4], "NEO"))
        return checkNeo(path, data);
    if (data.len >= 2 and readU16Le(data, 0) == 0xFFFF)
        return checkXex(path, data);
    // Lynx BLL: OUTPUT_FORMAT starts with SHORT(0x0880) → little-endian bytes 0x80 0x08.
    if (data.len >= 10 and data[0] == 0x80 and data[1] == 0x08)
        return checkBll(path, data);
    // Apple IIe ProDOS SYS: mos6502 init-stack signature (LDA #n; STA $00; LDA #n; STA $01).
    // Generated by llvm-mos init-stack.S for the appleii target.
    if (data.len >= 8 and
        data[0] == 0xA9 and data[2] == 0x85 and data[3] == 0x00 and
        data[4] == 0xA9 and data[6] == 0x85 and data[7] == 0x01)
        return checkSys(path, data);
    // mos-sim: load=$0200 header + data + 10-byte vectors trailer (FA FF 06 00 ...).
    if (data.len >= 14 and data[0] == 0x00 and data[1] == 0x02 and
        @as(usize, readU16Le(data, 2)) + 14 == data.len and
        readU16Le(data, data.len - 10) == 0xFFFA and readU16Le(data, data.len - 8) == 6)
        return checkSim(path, data);

    // Detect by file extension.
    const ext = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(ext, ".prg")) return checkPrg(path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".a26")) return checkA26(path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".pce")) return checkPce(path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".bll")) return checkBll(path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".rom")) return checkAtari8Cart(path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".sys")) return checkSys(path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".sfc") or std.ascii.eqlIgnoreCase(ext, ".smc"))
        return checkSfc(path, data);

    // Size-based fallback for extensionless cache-path files.
    // 2K/4K → always Atari 2600 (no other format uses these sizes here).
    if (data.len == 2048 or data.len == 4096)
        return checkA26(path, data);
    // 8K+ multiples of 8KB: distinguish PCE / Atari8-cart / A26 by vector heuristics.
    // - NMI vector (at len-6) == 0  →  Atari 2600 (VCS has no NMI, always zeroed)
    // - RESET vector (at len-4) < 0x8000  →  Atari 8-bit cartridge (code in low RAM)
    // - Otherwise  →  PC Engine (IRQ/RESET vectors point to fixed bank 0xE000–0xFFFF)
    if (data.len >= 8192 and data.len % 8192 == 0 and data.len <= 524288) {
        const nmi = readU16Le(data, data.len - 6);
        const reset = readU16Le(data, data.len - 4);
        const irq = readU16Le(data, data.len - 2);
        // A26: NMI unused (always 0), RESET and IRQ are identical and non-zero.
        if (nmi == 0x0000 and reset != 0 and irq == reset) return checkA26(path, data);
        // Atari 8-bit cart: RESET vector points to RAM/low-ROM (<0x8000), non-zero.
        if (reset != 0 and reset < 0x8000) return checkAtari8Cart(path, data);
        // SNES LoROM/HiROM: check internal header map-mode byte at $7FD5.
        // Valid SNES map modes: $20/$30 (LoROM), $21/$31 (HiROM), $23 (SA-1), $25 (ExHiROM).
        if (data.len >= 0x8000) {
            const map = data[0x7FD5];
            if (map == 0x20 or map == 0x21 or map == 0x23 or
                map == 0x25 or map == 0x30 or map == 0x31)
                return checkSfc(path, data);
        }
        // PCE (including banked ROMs where the upper bank is zero-padded).
        return checkPce(path, data);
    }

    // C64/MEGA65 PRG: first 2 bytes are a plausible Commodore load address.
    // Well-known values: 0x0801 (C64 BASIC start), 0x2001 (MEGA65 BASIC start).
    if (data.len >= 3) {
        const load = readU16Le(data, 0);
        if (load == 0x0801 or load == 0x2001)
            return checkPrg(path, data);
    }

    // Unknown format — report size but do not fail the build step.
    std.debug.print("{s}: [raw]  {d}B (format not recognised)\n", .{ path, data.len });
    return true;
}

// ── entry point ───────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const cwd = std.Io.Dir.cwd();

    var args_iter = try init.minimal.args.iterateAllocator(alloc);
    defer args_iter.deinit();
    _ = args_iter.next(); // skip argv[0]

    var any_arg = false;
    var all_ok = true;

    while (args_iter.next()) |path| {
        any_arg = true;
        const data = cwd.readFileAlloc(io, path, alloc, .unlimited) catch |err| {
            std.debug.print("{s}: ERROR: {s}\n", .{ path, @errorName(err) });
            all_ok = false;
            continue;
        };
        defer alloc.free(data);
        if (!checkFile(path, data)) all_ok = false;
    }

    if (!any_arg) usageExit();
    if (!all_ok) std.process.exit(1);
}
