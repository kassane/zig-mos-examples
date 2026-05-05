// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
//! bininfo — multi-format binary inspector for mos-examples output files.
//!
//! Usage: bininfo [flags] <file> [file...]
//!
//! Flags:
//!   -S, --sections     Show all ELF sections with types
//!   -n, --symbols      Show ELF symbol table
//!   -d, --dwarf        Show DWARF sections, CU list, subprograms, file tables
//!   -x, --xxd          Hex+ASCII dump of the file payload
//!       --xxd-limit N  Limit --xxd output to first N bytes (default: unlimited)
//!   -D, --disasm       6502 disassembly of the code payload
//!   -h, --help         Show this help and exit
//!
//! Detected formats (by magic bytes, then file extension):
//!   .nes  — NES iNES / NES 2.0 ROM
//!   .fds  — Famicom Disk System disk image (FDS\x1a magic or raw)
//!   .prg  — Commodore 64 / VIC-20 / CX16 / MEGA65 program file
//!   .a26  — Atari 2600 cartridge ROM (2K–32K)
//!   .xex  — Atari 8-bit DOS executable
//!   .neo  — Neo6502 load file
//!   .pce  — PC Engine cartridge ROM (raw, multiples of 8KB)
//!   .bll  — Atari Lynx Binary Load Library
//!   .rom  — Atari 8-bit standard cartridge ROM
//!   .sv   — Watara Supervision cartridge ROM (32KB, W65C02 vectors)
//!   .sys  — Apple IIe ProDOS SYS file (raw binary, load=$0800)
//!   .cvt  — GEOS Convert file (CBM GEOS target)
//!   .com  — CP/M-65 relocatable executable (elftocpm65 output)
//!   sim   — mos-sim binary (load=$0200 header + data + vectors trailer)
//!   osi-c1p-* — OSI Challenger 1P raw binary (TRIM(ram), load=$0200)
//!
//! Exit code: 0 if all files are valid, 1 if any file is missing or malformed.

const std = @import("std");
const dwarf = std.dwarf;
const elf = std.elf;

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

fn readVal(comptime T: type, data: []const u8, offset: usize) T {
    var v: T = undefined;
    @memcpy(std.mem.asBytes(&v), data[offset..][0..@sizeOf(T)]);
    return v;
}

fn elfMachName(m: elf.EM) []const u8 {
    return switch (@intFromEnum(m)) {
        0x1966 => "MOS6502",
        3 => "x86",
        0x3E => "x86-64",
        0xB7 => "AArch64",
        0x28 => "ARM",
        else => "?",
    };
}

fn elfTypeName(t: elf.ET) []const u8 {
    return switch (t) {
        .NONE => "NONE",
        .REL => "REL",
        .EXEC => "EXEC",
        .DYN => "DYN",
        .CORE => "CORE",
        else => "?",
    };
}

// nm-style type character derived from section attributes and symbol binding.
fn nmTypeChar(sh_type: u32, sh_flags: u32, shndx: u16, binding: u8) u8 {
    const is_local = binding == elf.STB_LOCAL;
    const is_weak = binding == elf.STB_WEAK;
    if (shndx == elf.SHN_UNDEF) return if (is_weak) 'w' else 'U';
    if (shndx == elf.SHN_ABS) return if (is_local) 'a' else 'A';
    if (shndx == elf.SHN_COMMON) return 'C';
    const c: u8 = if (sh_type == elf.SHT_NOBITS and (sh_flags & elf.SHF_ALLOC) != 0)
        'b' // BSS
    else if ((sh_flags & elf.SHF_EXECINSTR) != 0)
        't' // text
    else if ((sh_flags & elf.SHF_WRITE) != 0)
        'd' // data
    else
        'r'; // read-only
    if (is_weak) return if (c == 't') 'W' else 'V';
    return if (!is_local) std.ascii.toUpper(c) else c;
}

// ── DWARF / ELF extras ────────────────────────────────────────────────────────

fn shtypeName(t: u32) []const u8 {
    return switch (t) {
        0 => "NULL",
        1 => "PROGBITS",
        2 => "SYMTAB",
        3 => "STRTAB",
        4 => "RELA",
        5 => "HASH",
        7 => "NOTE",
        8 => "NOBITS",
        9 => "REL",
        11 => "DYNSYM",
        else => "?",
    };
}

fn readUleb128(data: []const u8, pos: *usize) u64 {
    var result: u64 = 0;
    var shift: u7 = 0;
    while (pos.* < data.len and shift < 64) {
        const b = data[pos.*];
        pos.* += 1;
        result |= @as(u64, b & 0x7F) << @truncate(shift);
        if (b & 0x80 == 0) break;
        shift += 7;
    }
    return result;
}

fn dwarfLangStr(lang: u32) []const u8 {
    inline for (@typeInfo(dwarf.LANG).@"struct".decls) |decl| {
        if (@as(u32, @field(dwarf.LANG, decl.name)) == lang) return decl.name;
    }
    return "?";
}

fn dumpDebugInfo(
    out: anytype,
    gpa: std.mem.Allocator,
    debug_info: []const u8,
    debug_abbrev: []const u8,
    debug_str: []const u8,
    debug_ranges: []const u8,
) void {
    const Dw = std.debug.Dwarf;
    const Id = Dw.Section.Id;

    var di = Dw{};
    di.sections[@intFromEnum(Id.debug_info)] = .{ .data = debug_info, .owned = false };
    di.sections[@intFromEnum(Id.debug_abbrev)] = .{ .data = debug_abbrev, .owned = false };
    if (debug_str.len > 0)
        di.sections[@intFromEnum(Id.debug_str)] = .{ .data = debug_str, .owned = false };
    if (debug_ranges.len > 0)
        di.sections[@intFromEnum(Id.debug_ranges)] = .{ .data = debug_ranges, .owned = false };

    di.open(gpa, .little) catch |err| {
        out.print("  (DWARF parse error: {})\n", .{err}) catch {};
        di.deinit(gpa);
        return;
    };
    defer di.deinit(gpa);

    out.print("  -- debug_info DIEs " ++ "-" ** 35 ++ "\n", .{}) catch {};

    for (di.compile_unit_list.items) |*cu| {
        const cu_name = cu.die.getAttrString(
            &di,
            .little,
            dwarf.AT.name,
            di.section(.debug_str),
            cu,
        ) catch "(unknown)";
        const cu_producer = cu.die.getAttrString(
            &di,
            .little,
            dwarf.AT.producer,
            di.section(.debug_str),
            cu,
        ) catch "";
        const cu_lang: u32 = blk: {
            for (cu.die.attrs) |attr| {
                if (attr.id == dwarf.AT.language) break :blk switch (attr.value) {
                    .udata => |v| @truncate(v),
                    .sdata => |v| @truncate(@as(u64, @bitCast(v))),
                    else => 0,
                };
            }
            break :blk 0;
        };
        out.print("  CU: {s}  lang={s}  producer=\"{s}\"\n", .{
            cu_name,
            dwarfLangStr(cu_lang),
            cu_producer[0..@min(cu_producer.len, 50)],
        }) catch {};
    }

    // scanAllCompileUnits only sets cu.pc_range from DW_AT_high_pc; CUs that use
    // DW_AT_ranges always get pc_range=null. List all named functions globally instead.
    var fn_count: u32 = 0;
    for (di.func_list.items) |func| {
        const fn_name = func.name orelse continue;
        if (func.pc_range) |fr| {
            out.print("    fn {s}  ${x:0>4}–${x:0>4}\n", .{ fn_name, fr.start, fr.end }) catch {};
        } else {
            out.print("    fn {s}\n", .{fn_name}) catch {};
        }
        fn_count += 1;
    }
    if (fn_count == 0) out.print("    (no subprograms)\n", .{}) catch {};
}

// Parse .debug_line and display source file tables.
fn dumpDebugLine(out: anytype, debug_line: []const u8) void {
    out.print("  -- debug_line file tables " ++ "-" ** 27 ++ "\n", .{}) catch {};
    var pos: usize = 0;
    var ltu: u32 = 0;
    while (pos + 10 <= debug_line.len) {
        const unit_len = readU32Le(debug_line, pos);
        pos += 4;
        if (unit_len < 6 or pos + unit_len > debug_line.len) break;
        const lt_end = pos + unit_len;
        const version = readU16Le(debug_line, pos);
        pos += 2;
        pos += 4; // header_length
        pos += 1; // minimum_instruction_length
        if (version >= 4 and pos < lt_end) pos += 1; // max_ops_per_instr
        pos += 3; // default_is_stmt, line_base, line_range
        if (pos >= lt_end) {
            pos = lt_end;
            ltu += 1;
            continue;
        }
        const opcode_base = debug_line[pos];
        pos += 1;
        if (opcode_base > 1) pos +|= @as(usize, opcode_base - 1);
        // Skip include directories
        while (pos < lt_end and debug_line[pos] != 0) {
            while (pos < lt_end and debug_line[pos] != 0) pos += 1;
            if (pos < lt_end) pos += 1;
        }
        if (pos < lt_end) pos += 1;
        // File names
        out.print("  LTU #{d}:\n", .{ltu}) catch {};
        var fi: u32 = 1;
        while (pos < lt_end and debug_line[pos] != 0) {
            const ns = pos;
            while (pos < lt_end and debug_line[pos] != 0) pos += 1;
            const fname = debug_line[ns..pos];
            if (pos < lt_end) pos += 1;
            _ = readUleb128(debug_line, &pos); // dir_idx
            _ = readUleb128(debug_line, &pos); // mod_time
            _ = readUleb128(debug_line, &pos); // file_size
            out.print("    {d}: {s}\n", .{ fi, fname }) catch {};
            fi += 1;
        }
        if (fi == 1) out.print("    (no files)\n", .{}) catch {};
        pos = lt_end;
        ltu += 1;
    }
}

// ── ELF inspector ─────────────────────────────────────────────────────────────

fn checkElf(out: anytype, gpa: std.mem.Allocator, path: []const u8, data: []const u8, opts: Opts) bool {
    if (data.len < @sizeOf(elf.Elf32_Ehdr)) {
        out.print("{s}: [ELF] ERROR: header truncated ({d} B)\n", .{ path, data.len }) catch {};
        return false;
    }
    const ei_class = data[4]; // 1=32-bit, 2=64-bit
    const ei_data = data[5]; // 1=LE, 2=BE
    if (ei_data != 1) {
        out.print("{s}: [ELF] big-endian ELF not supported by bininfo\n", .{path}) catch {};
        return true;
    }
    if (ei_class != 1) {
        out.print("{s}: [ELF64]  (64-bit ELF; summary only)\n", .{path}) catch {};
        return true;
    }

    const ehdr = readVal(elf.Elf32_Ehdr, data, 0);
    const e_type = ehdr.e_type; // elf.ET
    const e_machine = ehdr.e_machine; // elf.EM
    const e_entry = ehdr.e_entry;
    const e_shoff = ehdr.e_shoff;
    const e_shentsize = ehdr.e_shentsize;
    const e_shnum = ehdr.e_shnum;
    const e_shstrndx = ehdr.e_shstrndx;

    if (e_shoff == 0 or e_shentsize < 40 or
        @as(usize, e_shoff) + @as(usize, e_shnum) * e_shentsize > data.len)
    {
        out.print("{s}: [ELF32 {s}]  type={s}  entry=${x:0>4}  (no section table)\n", .{
            path, elfMachName(e_machine), elfTypeName(e_type), e_entry,
        }) catch {};
        return true;
    }

    // Locate shstrtab for section name lookup.
    const shstr_hdr = readVal(elf.Elf32_Shdr, data, @as(usize, e_shoff) + @as(usize, e_shstrndx) * e_shentsize);
    const shstr_off = shstr_hdr.sh_offset;
    const shstr_size = shstr_hdr.sh_size;
    const shstr: []const u8 = if (shstr_off + shstr_size <= data.len)
        data[shstr_off .. shstr_off + shstr_size]
    else
        &[_]u8{};

    // Count allocatable sections (for the summary).
    var alloc_count: u16 = 0;
    for (0..e_shnum) |i| {
        const sh = readVal(elf.Elf32_Shdr, data, @as(usize, e_shoff) + i * e_shentsize);
        if ((sh.sh_flags & elf.SHF_ALLOC) != 0) alloc_count += 1;
    }

    // Find .symtab; fall back to .dynsym for stripped binaries.
    var symtab_off: usize = 0;
    var symtab_size: usize = 0;
    var symtab_stridx: u32 = 0;
    var sym_local_end: u32 = 0;
    var found_symtab = false;
    for (0..e_shnum) |i| {
        const sh = readVal(elf.Elf32_Shdr, data, @as(usize, e_shoff) + i * e_shentsize);
        const sht = sh.sh_type;
        if (sht == elf.SHT_SYMTAB or (sht == elf.SHT_DYNSYM and !found_symtab)) {
            symtab_off = sh.sh_offset;
            symtab_size = sh.sh_size;
            symtab_stridx = sh.sh_link;
            sym_local_end = sh.sh_info; // sh_info = one past last LOCAL
            if (sht == elf.SHT_SYMTAB) {
                found_symtab = true;
                break;
            }
        }
    }

    // Locate symbol string table.
    var strtab_data: []const u8 = &[_]u8{};
    if (symtab_stridx < e_shnum) {
        const sh = readVal(elf.Elf32_Shdr, data, @as(usize, e_shoff) + @as(usize, symtab_stridx) * e_shentsize);
        const st_off = sh.sh_offset;
        const st_sz = sh.sh_size;
        if (st_off + st_sz <= data.len)
            strtab_data = data[st_off .. st_off + st_sz];
    }

    const sym_count = if (symtab_size >= @sizeOf(elf.Elf32_Sym)) symtab_size / @sizeOf(elf.Elf32_Sym) else 0;

    // One-line summary — always printed.
    out.print("{s}: [ELF32 {s}]  type={s}  entry=${x:0>4}  alloc-sections={d}  symbols={d}\n", .{
        path, elfMachName(e_machine), elfTypeName(e_type), e_entry, alloc_count, sym_count,
    }) catch {};

    // ── Section table (all sections, like llvm-readelf -S) ───────────────────
    if (opts.sections) {
        out.print("  -- Sections " ++ "-" ** 42 ++ "\n", .{}) catch {};
        out.print("  {s:<22} {s:<10} {s:>8}  {s}\n", .{ "Name", "Type", "Size", "Flags/VMA" }) catch {};
        for (0..e_shnum) |i| {
            const sh = readVal(elf.Elf32_Shdr, data, @as(usize, e_shoff) + i * e_shentsize);
            const sh_type = sh.sh_type;
            if (sh_type == elf.SHT_NULL) continue;
            const sh_flags = sh.sh_flags;
            const sh_addr = sh.sh_addr;
            const sh_size = sh.sh_size;
            const sh_name_off = sh.sh_name;

            const name: []const u8 = if (sh_name_off < shstr.len) blk: {
                const start = sh_name_off;
                var end = start;
                while (end < shstr.len and shstr[end] != 0) end += 1;
                break :blk shstr[start..end];
            } else "?";

            var fbuf: [12]u8 = undefined;
            var flen: usize = 0;
            if ((sh_flags & elf.SHF_ALLOC) != 0) {
                fbuf[flen] = 'A';
                flen += 1;
            }
            if ((sh_flags & elf.SHF_EXECINSTR) != 0) {
                fbuf[flen] = 'X';
                flen += 1;
            }
            if ((sh_flags & elf.SHF_WRITE) != 0) {
                fbuf[flen] = 'W';
                flen += 1;
            }
            if (sh_type == elf.SHT_NOBITS) {
                fbuf[flen] = 'B';
                flen += 1;
            }
            if ((sh_flags & elf.SHF_MERGE) != 0) {
                fbuf[flen] = 'M';
                flen += 1;
            }
            if ((sh_flags & elf.SHF_STRINGS) != 0) {
                fbuf[flen] = 'S';
                flen += 1;
            }
            if ((sh_flags & elf.SHF_TLS) != 0) {
                fbuf[flen] = 'T';
                flen += 1;
            }
            if ((sh_flags & elf.SHF_GROUP) != 0) {
                fbuf[flen] = 'G';
                flen += 1;
            }
            if ((sh_flags & elf.SHF_LINK_ORDER) != 0) {
                fbuf[flen] = 'l';
                flen += 1;
            }

            if ((sh_flags & elf.SHF_ALLOC) != 0) {
                out.print("  {s:<22} {s:<10} {d:>8}B  {s} @${x:0>4}\n", .{
                    name, shtypeName(sh_type), sh_size, fbuf[0..flen], sh_addr,
                }) catch {};
            } else {
                out.print("  {s:<22} {s:<10} {d:>8}B  {s}\n", .{
                    name, shtypeName(sh_type), sh_size, fbuf[0..flen],
                }) catch {};
            }
        }
    }

    // ── Symbol table (like nm, global + weak only unless very few symbols) ───
    if (opts.symbols) {
        if (sym_count == 0 or symtab_off + symtab_size > data.len) return true;

        // Build a per-symbol section cache for type resolution.
        // For each symbol we need its section's sh_type and sh_flags.
        out.print("  -- Symbols (nm) " ++ "-" ** 38 ++ "\n", .{}) catch {};

        const sym_base = symtab_off;
        const show_locals = sym_count < 64; // show locals only for small objects
        var printed: usize = 0;

        for (0..sym_count) |si| {
            const sym = readVal(elf.Elf32_Sym, data, sym_base + si * @sizeOf(elf.Elf32_Sym));
            if (sym.st_type() == elf.STT_SECTION or sym.st_type() == elf.STT_FILE) continue;
            const binding: u8 = @as(u8, sym.st_bind());

            // Skip local symbols unless object is small.
            if (!show_locals and binding == elf.STB_LOCAL) continue;

            const name: []const u8 = if (sym.st_name < strtab_data.len) blk: {
                var end = sym.st_name;
                while (end < strtab_data.len and strtab_data[end] != 0) end += 1;
                if (end == sym.st_name) continue; // empty name
                break :blk strtab_data[sym.st_name..end];
            } else continue;

            // Look up the section's type and flags for this symbol.
            var sh_type_for_sym: u32 = 0;
            var sh_flags_for_sym: u32 = 0;
            if (sym.st_shndx != elf.SHN_UNDEF and sym.st_shndx != elf.SHN_ABS and sym.st_shndx != elf.SHN_COMMON and
                sym.st_shndx < e_shnum)
            {
                const sym_sh = readVal(elf.Elf32_Shdr, data, @as(usize, e_shoff) + @as(usize, sym.st_shndx) * e_shentsize);
                sh_type_for_sym = sym_sh.sh_type;
                sh_flags_for_sym = sym_sh.sh_flags;
            }

            const tc = nmTypeChar(sh_type_for_sym, sh_flags_for_sym, sym.st_shndx, binding);
            out.print("  ${x:0>4} {c}  {s}\n", .{ sym.st_value, tc, name }) catch {};
            printed += 1;
        }
        if (printed == 0)
            out.print("  (no symbols — binary may be stripped)\n", .{}) catch {};
    }

    // ── MOS DWARF inventory ───────────────────────────────────────────────
    if (opts.dwarf and @intFromEnum(e_machine) == 0x1966) {
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
            const sh = readVal(elf.Elf32_Shdr, data, @as(usize, e_shoff) + i * e_shentsize);
            if ((sh.sh_flags & elf.SHF_ALLOC) != 0) continue; // DWARF is non-ALLOC
            const name_off = sh.sh_name;
            if (name_off >= shstr.len) continue;
            var name_end = name_off;
            while (name_end < shstr.len and shstr[name_end] != 0) name_end += 1;
            const sec_name = shstr[name_off..name_end];
            for (dwarf_names, 0..) |dn, di| {
                if (std.mem.eql(u8, sec_name, dn)) {
                    dwarf_offsets[di] = sh.sh_offset;
                    dwarf_sizes[di] = sh.sh_size;
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

            out.print("  -- DWARF " ++ "-" ** 45 ++ "\n", .{}) catch {};
            if (dwarf_ver > 0)
                out.print("  version=DWARFv{d}  compile-units={d}\n", .{ dwarf_ver, cu_count }) catch {};

            for (dwarf_names, 0..) |dn, di| {
                const sz = dwarf_sizes[di];
                if (sz > 0) {
                    out.print("  {s:<20} {d:>8}B\n", .{ dn, sz }) catch {};
                } else if (std.mem.eql(u8, dn, ".debug_frame")) {
                    out.print("  {s:<20}  (absent — no CFI; stack unwinding not supported on MOS)\n", .{dn}) catch {};
                }
            }

            // Parse .debug_info DIEs: CU list + subprogram names/PC ranges.
            const ab_off = dwarf_offsets[1];
            const ab_sz = dwarf_sizes[1];
            if (di_sz > 0 and di_off + di_sz <= data.len and
                ab_sz > 0 and ab_off + ab_sz <= data.len)
            {
                const str_off = dwarf_offsets[3];
                const str_sz = dwarf_sizes[3];
                const str_data: []const u8 = if (str_sz > 0 and str_off + str_sz <= data.len)
                    data[str_off..][0..str_sz]
                else
                    &[_]u8{};
                const rng_off = dwarf_offsets[4];
                const rng_sz = dwarf_sizes[4];
                const rng_data: []const u8 = if (rng_sz > 0 and rng_off + rng_sz <= data.len)
                    data[rng_off..][0..rng_sz]
                else
                    &[_]u8{};
                dumpDebugInfo(out, gpa, data[di_off..][0..di_sz], data[ab_off..][0..ab_sz], str_data, rng_data);
            }

            // Parse .debug_line file tables.
            const dl_off = dwarf_offsets[2];
            const dl_sz = dwarf_sizes[2];
            if (dl_sz > 0 and dl_off + dl_sz <= data.len)
                dumpDebugLine(out, data[dl_off..][0..dl_sz]);
        }
    }

    return true;
}

const help_text =
    \\Usage: bininfo [flags] <file> [file...]
    \\
    \\Flags:
    \\  -S, --sections     Show all ELF sections with types (like llvm-readelf -S)
    \\  -n, --symbols      Show ELF symbol table (like llvm-nm)
    \\  -d, --dwarf        Show DWARF sections, CU list, subprograms, file tables
    \\  -x, --xxd          Hex+ASCII dump of the file payload
    \\      --xxd-limit N  Limit --xxd output to first N bytes
    \\  -D, --disasm       6502 disassembly of the code payload
    \\  -h, --help         Show this help and exit
    \\
;

fn usageExit() noreturn {
    std.debug.print("{s}", .{help_text});
    std.process.exit(1);
}

fn helpExit() noreturn {
    std.debug.print("{s}", .{help_text});
    std.process.exit(0);
}

// ── format parsers ────────────────────────────────────────────────────────────

fn checkNes(out: anytype, path: []const u8, data: []const u8) bool {
    if (data.len < 16) {
        out.print("{s}: [NES] ERROR: file too small ({d} B)\n", .{ path, data.len }) catch {};
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

    out.print("{s}: [{s}]  mapper={d}  PRG={d}KB  CHR={d}KB  " ++
        "mirror={s}  battery={s}  payload={d}B\n", .{
        path,
        if (is_nes2) "NES 2.0" else "iNES 1.0",
        mapper,
        prg_kb,
        chr_kb,
        mirroring,
        if (battery) "yes" else "no",
        payload,
    }) catch {};
    return true;
}

fn checkPrg(out: anytype, path: []const u8, data: []const u8) bool {
    if (data.len < 3) {
        out.print("{s}: [PRG] ERROR: file too small ({d} B)\n", .{ path, data.len }) catch {};
        return false;
    }
    const load = readU16Le(data, 0);
    const size: u16 = @truncate(data.len - 2);
    const end = load +% size -% 1;
    out.print("{s}: [CBM PRG]  load=${x:0>4}  size={d}B  end=${x:0>4}\n", .{
        path, load, size, end,
    }) catch {};
    return true;
}

fn checkA26(out: anytype, path: []const u8, data: []const u8) bool {
    const len = data.len;
    if (len != 2048 and len != 4096 and len != 8192 and len != 16384 and len != 32768) {
        out.print("{s}: [A26] ERROR: unexpected ROM size {d}B (expected 2K/4K/8K/16K/32K)\n", .{
            path, len,
        }) catch {};
        return false;
    }
    // 6502 vectors are at the end of the address space mapped by the ROM.
    // For any cart size: last 6 bytes = NMI(2) + RESET(2) + IRQ(2).
    const nmi = readU16Le(data, len - 6);
    const reset = readU16Le(data, len - 4);
    const irq = readU16Le(data, len - 2);
    out.print("{s}: [Atari 2600]  size={d}KB  NMI=${x:0>4}  RESET=${x:0>4}  IRQ=${x:0>4}\n", .{
        path, len / 1024, nmi, reset, irq,
    }) catch {};
    return true;
}

fn checkXex(out: anytype, path: []const u8, data: []const u8) bool {
    if (data.len < 6 or readU16Le(data, 0) != 0xFFFF) {
        out.print("{s}: [XEX] ERROR: missing 0xFFFF magic\n", .{path}) catch {};
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
            out.print("{s}: [XEX] ERROR: segment end ${x:0>4} < start ${x:0>4}\n", .{ path, end, start }) catch {};
            ok = false;
            break;
        }
        const seg_len: usize = @as(usize, end) - start + 1;
        if (pos + seg_len > data.len) {
            out.print("{s}: [XEX] ERROR: segment data truncated\n", .{path}) catch {};
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
        out.print("{s}: [Atari XEX]  segments={d}  run=${x:0>4}  size={d}B\n", .{
            path, seg_count, ra, data.len,
        }) catch {};
    } else {
        out.print("{s}: [Atari XEX]  segments={d}  run=(none)  size={d}B\n", .{
            path, seg_count, data.len,
        }) catch {};
    }
    return true;
}

fn checkSv(out: anytype, path: []const u8, data: []const u8) bool {
    // Watara Supervision: 32KB raw ROM, W65C02 vectors at end.
    // RESET at data[0x7FFC], NMI at data[0x7FFA], IRQ at data[0x7FFE].
    if (data.len != 32768) {
        out.print("{s}: [SV] ERROR: expected 32768 B, got {d}\n", .{ path, data.len }) catch {};
        return false;
    }
    const nmi = readU16Le(data, 0x7FFA);
    const reset = readU16Le(data, 0x7FFC);
    const irq = readU16Le(data, 0x7FFE);
    out.print("{s}: [Supervision]  size=32KB  RESET=${x:0>4}  NMI=${x:0>4}  IRQ=${x:0>4}\n", .{
        path, reset, nmi, irq,
    }) catch {};
    return true;
}

fn checkDodo(out: anytype, path: []const u8) bool {
    // Dodo game binary: 8KB FULL(fram) dump, $5800–$79FF.
    // OS jumps to $5900, so first $100 bytes are zero padding; no 6502 vectors at end.
    out.print("{s}: [Dodo]  size=8KB  entry=$5900\n", .{path}) catch {};
    return true;
}

fn checkNeo(out: anytype, path: []const u8, data: []const u8) bool {
    // .neo header: 03 'N' 'E' 'O' maj min exec_lo exec_hi ctrl load_lo load_hi sz_lo sz_hi nul
    if (data.len < 14 or
        data[0] != 0x03 or data[1] != 'N' or data[2] != 'E' or data[3] != 'O')
    {
        out.print("{s}: [NEO] ERROR: invalid magic\n", .{path}) catch {};
        return false;
    }
    const ver_maj = data[4];
    const ver_min = data[5];
    const exec = readU16Le(data, 6);
    const load = readU16Le(data, 9);
    const size = readU16Le(data, 11);
    out.print("{s}: [Neo6502]  ver={d}.{d}  exec=${x:0>4}  load=${x:0>4}  payload={d}B\n", .{
        path, ver_maj, ver_min, exec, load, size,
    }) catch {};
    return true;
}

const SnesHeader = struct {
    hdr_off: usize,
    vec_reset: usize,
    vec_nmi: usize,
};

fn snesDetectHeader(data: []const u8) SnesHeader {
    const valid_modes = [_]u8{ 0x20, 0x21, 0x23, 0x25, 0x30, 0x31 };
    // HiROM header at $FFC0; LoROM at $7FC0. Try HiROM first when map_mode matches.
    const candidates = [_]SnesHeader{
        .{ .hdr_off = 0xFFC0, .vec_reset = 0xFFFC, .vec_nmi = 0xFFEA },
        .{ .hdr_off = 0x7FC0, .vec_reset = 0x7FFC, .vec_nmi = 0x7FEA },
    };
    for (candidates) |c| {
        if (data.len < c.hdr_off + 32) continue;
        const m = data[c.hdr_off + 0x15];
        for (valid_modes) |v| if (m == v) return c;
    }
    return candidates[1]; // default LoROM
}

fn checkSfc(out: anytype, path: []const u8, raw: []const u8) bool {
    // Strip 512-byte SMC copier header if present (size % 1024 == 512).
    const data = if (raw.len % 1024 == 512) raw[512..] else raw;
    const len = data.len;
    if (len < 32768 or (len % 32768) != 0) {
        out.print("{s}: [SFC] ERROR: unexpected size {d}B (expected multiple of 32KB)\n", .{ path, raw.len }) catch {};
        return false;
    }
    const h = snesDetectHeader(data);
    const hdr = h.hdr_off;
    const map_mode = data[hdr + 0x15];
    const rom_sz_byte = data[hdr + 0x17];
    const chksum = readU16Le(data, hdr + 0x1E);
    const chksum_comp = readU16Le(data, hdr + 0x1C);
    const chk_ok = (chksum ^ chksum_comp) == 0xFFFF;

    // Title: 21 ASCII bytes at hdr, space-padded — trim trailing spaces.
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

    const reset = readU16Le(data, h.vec_reset);
    const nmi_native = readU16Le(data, h.vec_nmi);
    const rom_kb: u32 = if (rom_sz_byte < 14) @as(u32, 1) << @truncate(rom_sz_byte) else 0;

    out.print(
        "{s}: [SNES {s}]  size={d}KB  title=\"{s}\"  map=${x:0>2}  RESET=${x:0>4}  NMI(native)=${x:0>4}  rom={d}KB  chk={s}\n",
        .{ path, map_name, len / 1024, title[0..tlen], map_mode, reset, nmi_native, rom_kb, if (chk_ok) "ok" else "BAD" },
    ) catch {};
    return true;
}

fn checkPce(out: anytype, path: []const u8, data: []const u8) bool {
    const len = data.len;
    if (len == 0 or (len % 8192) != 0) {
        out.print("{s}: [PCE] ERROR: unexpected size {d}B (expected multiple of 8KB)\n", .{ path, len }) catch {};
        return false;
    }
    // RESET vector is at the last 2 bytes of the fixed bank (0xFFFE in addr space).
    const reset = readU16Le(data, len - 2);
    out.print("{s}: [PC Engine]  size={d}KB  reset=${x:0>4}\n", .{
        path, len / 1024, reset,
    }) catch {};
    return true;
}

fn checkBll(out: anytype, path: []const u8, data: []const u8) bool {
    // Lynx BLL header: SHORT(0x0880)=0x80,0x08  BYTE hi_load BYTE lo_load  BYTE hi_len BYTE lo_len  "BS93"
    if (data.len < 10 or data[0] != 0x80 or data[1] != 0x08) {
        out.print("{s}: [BLL] ERROR: invalid BLL magic\n", .{path}) catch {};
        return false;
    }
    const load: u16 = (@as(u16, data[2]) << 8) | data[3]; // big-endian
    const total: u16 = (@as(u16, data[4]) << 8) | data[5]; // big-endian
    const data_size: u16 = if (total >= 10) total - 10 else 0;
    out.print("{s}: [Lynx BLL]  load=${x:0>4}  data={d}B  total={d}B\n", .{
        path, load, data_size, total,
    }) catch {};
    return true;
}

fn checkSys(out: anytype, path: []const u8, data: []const u8) bool {
    // ProDOS SYS file: raw 6502 binary, load address $0800, no file header.
    if (data.len == 0) {
        out.print("{s}: [Apple IIe SYS] ERROR: empty file\n", .{path}) catch {};
        return false;
    }
    const load: u16 = 0x0800;
    const end: u16 = load +% @as(u16, @truncate(data.len)) -% 1;
    out.print("{s}: [Apple IIe ProDOS SYS]  load=${x:0>4}  size={d}B  end=${x:0>4}\n", .{
        path, load, data.len, end,
    }) catch {};
    return true;
}

fn checkSim(out: anytype, path: []const u8, data: []const u8) bool {
    // sim OUTPUT_FORMAT: SHORT($0200) SHORT(data_len) TRIM(ram)
    //   followed by: SHORT($FFFA) SHORT(6) SHORT(nmi) SHORT(reset) SHORT(irq)
    if (data.len < 14) {
        out.print("{s}: [mos-sim] ERROR: file too small ({d} B)\n", .{ path, data.len }) catch {};
        return false;
    }
    const data_len = readU16Le(data, 2);
    if (@as(usize, data_len) + 14 != data.len) {
        out.print("{s}: [mos-sim] ERROR: size mismatch (header says {d}B data, file={d}B)\n", .{
            path, data_len, data.len,
        }) catch {};
        return false;
    }
    const vbase = data.len - 10;
    const nmi = readU16Le(data, vbase + 4);
    const reset = readU16Le(data, vbase + 6);
    const irq = readU16Le(data, vbase + 8);
    out.print("{s}: [mos-sim]  load=$0200  code={d}B  NMI=${x:0>4}  RESET=${x:0>4}  IRQ=${x:0>4}\n", .{
        path, data_len, nmi, reset, irq,
    }) catch {};
    return true;
}

fn checkAtari8Cart(out: anytype, path: []const u8, data: []const u8) bool {
    const len = data.len;
    if (len != 8192 and len != 16384 and len != 32768 and len != 65536) {
        out.print("{s}: [A8CART] ERROR: unexpected size {d}B (expected 8K/16K/32K/64K)\n", .{ path, len }) catch {};
        return false;
    }
    // Run address at 0xBFFE–0xBFFF (little-endian) = last 2 bytes for 8KB ROM at 0xA000.
    const run = readU16Le(data, len - 2);
    out.print("{s}: [Atari 8-bit cart]  size={d}KB  run=${x:0>4}\n", .{
        path, len / 1024, run,
    }) catch {};
    return true;
}

fn checkFds(out: anytype, path: []const u8, data: []const u8) bool {
    if (data.len == 0) {
        out.print("{s}: [FDS] ERROR: empty file\n", .{path}) catch {};
        return false;
    }
    // Headered format: "FDS\x1a" + 1-byte side count + 11 reserved + 65500*sides disk data.
    if (data.len >= 4 and std.mem.eql(u8, data[0..4], "FDS\x1a")) {
        if (data.len < 16) {
            out.print("{s}: [FDS] ERROR: header truncated ({d} B)\n", .{ path, data.len }) catch {};
            return false;
        }
        const sides = data[4];
        const expected: usize = 16 + @as(usize, sides) * 65500;
        out.print("{s}: [FDS]  sides={d}  size={d}B{s}\n", .{
            path, sides, data.len, if (data.len == expected) "" else "  (WARN: size mismatch)",
        }) catch {};
        return true;
    }
    // Raw (headerless) FDS binary — llvm-mos-sdk FDS target produces TRIM(prg_ram).
    // prg_ram starts at $6000; the FDS BIOS loads and calls _start from there.
    // The .vectors (INFO) section is informational only and does NOT appear in the output,
    // so the last bytes are code/data — not 6502 vectors.
    if (data.len > 0) {
        out.print("{s}: [FDS raw]  load=$6000  size={d}B  end=${x:0>4}\n", .{
            path, data.len, 0x6000 + data.len - 1,
        }) catch {};
    } else {
        out.print("{s}: [FDS raw]  size={d}B\n", .{ path, data.len }) catch {};
    }
    return true;
}

fn checkCvt(out: anytype, path: []const u8, data: []const u8) bool {
    // GEOS Convert (.cvt) format: produced by llvm-mos-sdk geos-cbm target.
    // Header starts with 0x03 0x00 0xFF followed by ASCII description.
    if (data.len < 3 or data[0] != 0x03 or data[1] != 0x00 or data[2] != 0xFF) {
        out.print("{s}: [GEOS CVT] ERROR: unrecognised header\n", .{path}) catch {};
        return false;
    }
    // Description string follows at byte 3, null-terminated within the 256-byte header.
    var desc_end: usize = 3;
    while (desc_end < data.len and desc_end < 255 and data[desc_end] != 0) desc_end += 1;
    const desc = data[3..desc_end];
    out.print("{s}: [GEOS CVT]  size={d}B  desc=\"{s}\"\n", .{ path, data.len, desc }) catch {};
    return true;
}

fn checkCpm65(out: anytype, path: []const u8, data: []const u8) bool {
    // CP/M-65 relocatable .com produced by elftocpm65.
    //   [0]    ZP size in bytes
    //   [1]    total memory size in 256-byte pages
    //   [2:3]  pblock address (LE u16)
    //   [4]    0x4C (JMP opcode for BDOS stub)
    if (data.len < 8 or data[4] != 0x4C) {
        out.print("{s}: [CP/M-65 .com] ERROR: unexpected header\n", .{path}) catch {};
        return false;
    }
    const zp_size = data[0];
    const mem_pages = data[1];
    const pblock = readU16Le(data, 2);
    out.print("{s}: [CP/M-65 .com]  size={d}B  zp={d}B  mem={d}pages  pblock=${x:0>4}\n", .{
        path, data.len, zp_size, mem_pages, pblock,
    }) catch {};
    return true;
}

fn checkOsiC1p(out: anytype, path: []const u8, data: []const u8) bool {
    // OSI Challenger 1P: raw TRIM(ram) binary, load=$0200, no file header.
    out.print("{s}: [OSI C1P]  load=$0200  size={d}B  end=${x:0>4}\n", .{
        path, data.len, 0x0200 + data.len - 1,
    }) catch {};
    return true;
}

// ── flags ─────────────────────────────────────────────────────────────────────

const Opts = struct {
    sections: bool = false,
    symbols: bool = false,
    dwarf: bool = false,
    xxd: bool = false,
    xxd_limit: usize = std.math.maxInt(usize),
    disasm: bool = false,
};

// ── xxd dump (stdout, file-relative offsets) ──────────────────────────────────

fn xxdDump(out: anytype, data: []const u8, limit: usize) void {
    const n = @min(data.len, limit);
    var i: usize = 0;
    while (i < n) {
        const row_end = @min(i + 16, n);
        out.print("  {x:0>8}: ", .{i}) catch {};
        var j: usize = 0;
        while (j < 16) : (j += 1) {
            if (j == 8) out.print(" ", .{}) catch {};
            if (i + j < n) {
                out.print("{x:0>2}{s}", .{ data[i + j], if (j % 2 == 1) " " else "" }) catch {};
            } else {
                out.print("  {s}", .{if (j % 2 == 1) " " else ""}) catch {};
            }
        }
        out.print(" ", .{}) catch {};
        for (data[i..row_end]) |b| {
            out.print("{c}", .{if (b >= 0x20 and b < 0x7F) b else '.'}) catch {};
        }
        out.print("\n", .{}) catch {};
        i = row_end;
    }
    if (data.len > n) {
        out.print("  ... ({d} more bytes)\n", .{data.len - n}) catch {};
    }
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
    _ = M; // used via OpcodeMode literals above
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

        // Raw bytes column (fixed-width: up to 3 bytes + padding)
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

// ── dispatch ──────────────────────────────────────────────────────────────────

fn checkFile(out: anytype, gpa: std.mem.Allocator, path: []const u8, data: []const u8, opts: Opts) bool {
    // Detect by magic first.
    if (data.len >= 4 and std.mem.eql(u8, data[0..4], "\x7FELF"))
        return checkElf(out, gpa, path, data, opts);
    if (data.len >= 4 and std.mem.eql(u8, data[0..4], "NES\x1a"))
        return checkNes(out, path, data);
    if (data.len >= 4 and std.mem.eql(u8, data[0..4], "FDS\x1a"))
        return checkFds(out, path, data);
    if (data.len >= 3 and data[0] == 0x03 and data[1] == 0x00 and data[2] == 0xFF)
        return checkCvt(out, path, data);
    if (data.len >= 4 and data[0] == 0x03 and std.mem.eql(u8, data[1..4], "NEO"))
        return checkNeo(out, path, data);
    if (data.len >= 2 and readU16Le(data, 0) == 0xFFFF)
        return checkXex(out, path, data);
    // Lynx BLL: OUTPUT_FORMAT starts with SHORT(0x0880) → little-endian bytes 0x80 0x08.
    if (data.len >= 10 and data[0] == 0x80 and data[1] == 0x08)
        return checkBll(out, path, data);
    // Apple IIe ProDOS SYS: mos6502 init-stack signature (LDA #n; STA $00; LDA #n; STA $01).
    // Generated by llvm-mos init-stack.S for the appleii target.
    if (data.len >= 8 and
        data[0] == 0xA9 and data[2] == 0x85 and data[3] == 0x00 and
        data[4] == 0xA9 and data[6] == 0x85 and data[7] == 0x01)
        return checkSys(out, path, data);
    // mos-sim: load=$0200 header + data + 10-byte vectors trailer (FA FF 06 00 ...).
    if (data.len >= 14 and data[0] == 0x00 and data[1] == 0x02 and
        @as(usize, readU16Le(data, 2)) + 14 == data.len and
        readU16Le(data, data.len - 10) == 0xFFFA and readU16Le(data, data.len - 8) == 6)
        return checkSim(out, path, data);

    // Detect by file extension.
    const ext = std.fs.path.extension(path);
    if (std.ascii.eqlIgnoreCase(ext, ".prg")) return checkPrg(out, path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".fds")) return checkFds(out, path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".cvt")) return checkCvt(out, path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".com")) return checkCpm65(out, path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".a26")) return checkA26(out, path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".pce")) return checkPce(out, path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".bll")) return checkBll(out, path, data);
    // .rom: Atari 8-bit carts (RESET < $8000, ≤ 64KB) or larger banked carts (megacart/XEGS/5200)
    //        or Ben Eater 6502 32KB ROMs (RESET $8000–$DFFF).
    if (std.ascii.eqlIgnoreCase(ext, ".rom")) {
        if (data.len >= 8192 and data.len % 8192 == 0 and data.len <= 524288) {
            const reset = readU16Le(data, data.len - 4);
            if (reset != 0 and reset < 0x8000 and data.len <= 65536)
                return checkAtari8Cart(out, path, data);
            if (reset >= 0x8000 and reset < 0xE000 and data.len == 32768)
                return checkSv(out, path, data);
        }
        // Large banked Atari 8-bit / 5200 cart or other raw ROM.
        out.print("{s}: [ROM]  size={d}KB\n", .{ path, data.len / 1024 }) catch {};
        return true;
    }
    if (std.ascii.eqlIgnoreCase(ext, ".sys")) return checkSys(out, path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".sv")) return checkSv(out, path, data);
    if (std.ascii.eqlIgnoreCase(ext, ".sfc") or std.ascii.eqlIgnoreCase(ext, ".smc"))
        return checkSfc(out, path, data);

    // Size-based fallback for extensionless cache-path files ONLY.
    // If there is any file extension (e.g. .bin, .dat) and it wasn't matched above,
    // skip size heuristics — they produce false positives on arbitrary raw files.
    if (ext.len > 0) {
        out.print("{s}: [raw]  {d}B (format not recognised)\n", .{ path, data.len }) catch {};
        return true;
    }
    // 2K/4K → always Atari 2600 (no other format uses these sizes here).
    if (data.len == 2048 or data.len == 4096)
        return checkA26(out, path, data);
    // 8K+ multiples of 8KB: distinguish PCE / Atari8-cart / A26 by vector heuristics.
    // - NMI vector (at len-6) == 0  →  Atari 2600 (VCS has no NMI, always zeroed)
    // - RESET vector (at len-4) < 0x8000  →  Atari 8-bit cartridge (code in low RAM)
    // - Otherwise  →  PC Engine (IRQ/RESET vectors point to fixed bank 0xE000–0xFFFF)
    if (data.len >= 8192 and data.len % 8192 == 0 and data.len <= 524288) {
        const nmi = readU16Le(data, data.len - 6);
        const reset = readU16Le(data, data.len - 4);
        const irq = readU16Le(data, data.len - 2);
        // A26: NMI unused (always 0), RESET and IRQ are identical and non-zero.
        if (nmi == 0x0000 and reset != 0 and irq == reset) return checkA26(out, path, data);
        // Atari 8-bit cart: RESET vector points to RAM/low-ROM (<0x8000), non-zero.
        if (reset != 0 and reset < 0x8000) return checkAtari8Cart(out, path, data);
        // SNES LoROM/HiROM: check internal header map-mode byte at $7FD5.
        // Valid SNES map modes: $20/$30 (LoROM), $21/$31 (HiROM), $23 (SA-1), $25 (ExHiROM).
        if (data.len >= 0x8000) {
            const map = data[0x7FD5];
            if (map == 0x20 or map == 0x21 or map == 0x23 or
                map == 0x25 or map == 0x30 or map == 0x31)
                return checkSfc(out, path, data);
        }
        // Supervision: 32KB ROM with RESET in $8000–$DFFF.
        // PCE last-bank vectors always point to $E000+; Supervision RESET is $8000–$DFFF.
        if (data.len == 32768 and reset >= 0x8000 and reset < 0xE000)
            return checkSv(out, path, data);
        // Dodo: 8KB FULL(fram) dump; first $100 bytes are zero padding ($5800-$58FF gap),
        // code starts at $5900 (offset $100), no 6502 vectors at end (all zero).
        if (data.len == 8192 and nmi == 0 and reset == 0 and irq == 0 and
            data[0x100] != 0)
        {
            var all_zero = true;
            for (data[0..0x100]) |b| if (b != 0) {
                all_zero = false;
                break;
            };
            if (all_zero) return checkDodo(out, path);
        }
        // PCE (including banked ROMs where the upper bank is zero-padded).
        return checkPce(out, path, data);
    }

    // CBM PRG: first 2 bytes are a plausible Commodore/VIC-20 load address.
    // Well-known values:
    //   $0401 — VIC-20 unexpanded BASIC start
    //   $0801 — C64 BASIC start
    //   $1001 — VIC-20 +3K expansion BASIC start
    //   $1201 — VIC-20 +8K/+16K/+24K expansion start (used by vic20-hello)
    //   $1C01 — C128 BASIC start (bank-switched BASIC at $1C00)
    //   $2001 — MEGA65 BASIC start
    if (data.len >= 3) {
        const load = readU16Le(data, 0);
        if (load == 0x0401 or load == 0x0801 or
            load == 0x1001 or load == 0x1201 or
            load == 0x1C01 or load == 0x2001)
            return checkPrg(out, path, data);
    }

    // OSI Challenger 1P: extensionless raw binary, detected by basename containing "osi-c1p".
    const basename = std.fs.path.basename(path);
    if (std.mem.indexOf(u8, basename, "osi-c1p") != null)
        return checkOsiC1p(out, path, data);

    // Unknown format — report size but do not fail the build step.
    out.print("{s}: [raw]  {d}B (format not recognised)\n", .{ path, data.len }) catch {};
    return true;
}

// ── entry point ───────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const cwd = std.Io.Dir.cwd();
    var stdout_buf: [4096]u8 = undefined;
    var stdout_fw = std.Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &stdout_fw.interface;

    var args_iter = try init.minimal.args.iterateAllocator(alloc);
    defer args_iter.deinit();
    _ = args_iter.next(); // skip argv[0]

    // Collect all args upfront so we can do two passes (flags then files).
    var args_list: std.ArrayListUnmanaged([]const u8) = .empty;
    defer args_list.deinit(alloc);
    while (args_iter.next()) |arg| try args_list.append(alloc, arg);

    var opts = Opts{};
    var any_file = false;
    var all_ok = true;

    // Pass 1: collect all flags (so flags after filenames still apply).
    {
        var i: usize = 0;
        while (i < args_list.items.len) : (i += 1) {
            const arg = args_list.items[i];
            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) helpExit();
            if (std.mem.eql(u8, arg, "--sections") or std.mem.eql(u8, arg, "-S")) {
                opts.sections = true;
            } else if (std.mem.eql(u8, arg, "--symbols") or std.mem.eql(u8, arg, "-n")) {
                opts.symbols = true;
            } else if (std.mem.eql(u8, arg, "--dwarf") or std.mem.eql(u8, arg, "-d")) {
                opts.dwarf = true;
            } else if (std.mem.eql(u8, arg, "--xxd") or std.mem.eql(u8, arg, "-x")) {
                opts.xxd = true;
            } else if (std.mem.eql(u8, arg, "--disasm") or std.mem.eql(u8, arg, "-D")) {
                opts.disasm = true;
            } else if (std.mem.eql(u8, arg, "--xxd-limit")) {
                i += 1;
                if (i >= args_list.items.len) {
                    std.debug.print("bininfo: --xxd-limit requires a value\n", .{});
                    std.process.exit(1);
                }
                opts.xxd_limit = std.fmt.parseUnsigned(usize, args_list.items[i], 10) catch {
                    std.debug.print("bininfo: --xxd-limit: invalid number '{s}'\n", .{args_list.items[i]});
                    std.process.exit(1);
                };
            } else if (std.mem.startsWith(u8, arg, "-")) {
                std.debug.print("bininfo: unknown flag '{s}'\n", .{arg});
                usageExit();
            }
            // non-flag args (file paths) are processed in pass 2
        }
    }

    // Pass 2: process files with all flags already resolved.
    {
        var i: usize = 0;
        while (i < args_list.items.len) : (i += 1) {
            const arg = args_list.items[i];
            if (std.mem.eql(u8, arg, "--xxd-limit")) {
                i += 1; // skip the value token consumed in pass 1
                continue;
            }
            if (std.mem.startsWith(u8, arg, "-")) continue; // flag — already handled

            any_file = true;
            const data = cwd.readFileAlloc(io, arg, alloc, .unlimited) catch |err| {
                std.debug.print("{s}: ERROR: {s}\n", .{ arg, @errorName(err) });
                all_ok = false;
                continue;
            };
            defer alloc.free(data);

            if (!checkFile(stdout, alloc, arg, data, opts)) all_ok = false;

            if (opts.xxd) {
                stdout.print("  -- xxd " ++ "-" ** 47 ++ "\n", .{}) catch {};
                xxdDump(stdout, data, opts.xxd_limit);
            }
            if (opts.disasm) {
                // Heuristic: for PRG files (load addr in first 2 bytes), skip header.
                const is_prg = data.len >= 3 and
                    std.ascii.eqlIgnoreCase(std.fs.path.extension(arg), ".prg");
                const load_addr: u16 = if (is_prg) readU16Le(data, 0) else 0;
                const payload: []const u8 = if (is_prg) data[2..] else data;
                stdout.print("  -- disasm (6502) load=${x:0>4} " ++ "-" ** 24 ++ "\n", .{load_addr}) catch {};
                disasm6502(stdout, payload, load_addr);
            }
            stdout_fw.flush() catch {};
        }
    }

    if (!any_file) usageExit();
    stdout_fw.flush() catch {};
    if (!all_ok) std.process.exit(1);
}
