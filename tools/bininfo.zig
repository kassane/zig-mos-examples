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
//!
//! Exit code: 0 if all files are valid, 1 if any file is missing or malformed.

const std = @import("std");

// ── helpers ──────────────────────────────────────────────────────────────────

fn readU16Le(data: []const u8, off: usize) u16 {
    return @as(u16, data[off]) | (@as(u16, data[off + 1]) << 8);
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
