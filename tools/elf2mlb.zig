// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
// Converts a MOS ELF (with .symtab) to a Mesen label file (.mlb).
// Usage: elf2mlb <binary> <output.mlb> <output.elf>
//   <binary>     - path to the NES binary in the build cache
//                  (the ELF is the sibling file with ".elf" appended)
//   <output.mlb> - destination for the Mesen label file
//   <output.elf> - destination to copy the debug ELF

const std = @import("std");
const elf = std.elf;

// Mesen MLB address-type prefix + offset for the NES CPU address space.
// Mesen expects ROM/RAM *offsets*, not CPU addresses, for P: and S: labels.
fn mlbEntry(addr: u32) ?struct { prefix: []const u8, offset: u32 } {
    return switch (addr) {
        0x0000...0x00ff => .{ .prefix = "G", .offset = addr }, // zero page: addr == offset
        0x0100...0x1fff => .{ .prefix = "R", .offset = addr }, // work RAM:  addr == offset
        0x6000...0x7fff => .{ .prefix = "S", .offset = addr - 0x6000 }, // SRAM offset from $6000
        0x8000...0xffff => .{ .prefix = "P", .offset = addr - 0x8000 }, // PRG ROM offset from $8000
        else => null,
    };
}

fn isInternal(name: []const u8) bool {
    if (name.len == 0) return true;
    if (std.mem.startsWith(u8, name, "__")) return true;
    if (std.mem.startsWith(u8, name, ".")) return true;
    return false;
}

fn readVal(comptime T: type, data: []const u8, offset: usize) T {
    var v: T = undefined;
    @memcpy(std.mem.asBytes(&v), data[offset..][0..@sizeOf(T)]);
    return v;
}

fn usageExit() noreturn {
    std.debug.print("Usage: elf2mlb <binary> <output.mlb> <output.elf>\n", .{});
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const cwd = std.Io.Dir.cwd();

    var args_iter = try init.minimal.args.iterateAllocator(alloc);
    defer args_iter.deinit();
    _ = args_iter.next(); // skip argv[0]

    const bin_path = args_iter.next() orelse usageExit();
    const mlb_path = args_iter.next() orelse usageExit();
    const elf_out_path = args_iter.next() orelse usageExit();

    const elf_path = try std.fmt.allocPrint(alloc, "{s}.elf", .{bin_path});
    defer alloc.free(elf_path);

    // Copy ELF to the install output directory.
    cwd.copyFile(elf_path, cwd, elf_out_path, io, .{ .replace = true }) catch |err| {
        std.debug.print("elf2mlb: cannot copy {s}: {}\n", .{ elf_path, err });
        std.process.exit(1);
    };

    // Read the ELF for symbol extraction.
    const elf_data = cwd.readFileAlloc(io, elf_path, alloc, .unlimited) catch |err| {
        std.debug.print("elf2mlb: cannot read {s}: {}\n", .{ elf_path, err });
        std.process.exit(1);
    };
    defer alloc.free(elf_data);

    if (elf_data.len < @sizeOf(elf.Elf32_Ehdr)) {
        std.debug.print("elf2mlb: {s}: file too small\n", .{elf_path});
        std.process.exit(1);
    }

    const ehdr = readVal(elf.Elf32_Ehdr, elf_data, 0);
    if (!std.mem.eql(u8, ehdr.e_ident[0..4], "\x7fELF") or ehdr.e_ident[4] != 1) {
        std.debug.print("elf2mlb: {s}: not a 32-bit ELF\n", .{elf_path});
        std.process.exit(1);
    }

    // Section name string table.
    const shstrtab_off = ehdr.e_shoff + @as(u32, ehdr.e_shstrndx) * ehdr.e_shentsize;
    const shstrtab_hdr = readVal(elf.Elf32_Shdr, elf_data, shstrtab_off);
    const shstrtab = elf_data[shstrtab_hdr.sh_offset..][0..shstrtab_hdr.sh_size];

    // Find .symtab and .strtab.
    var symtab_offset: u32 = 0;
    var symtab_size: u32 = 0;
    var strtab_offset: u32 = 0;
    var strtab_size: u32 = 0;

    for (0..ehdr.e_shnum) |i| {
        const off = ehdr.e_shoff + @as(u32, @intCast(i)) * ehdr.e_shentsize;
        const shdr = readVal(elf.Elf32_Shdr, elf_data, off);
        const sec_name = std.mem.sliceTo(shstrtab[shdr.sh_name..], 0);
        if (std.mem.eql(u8, sec_name, ".symtab")) {
            symtab_offset = shdr.sh_offset;
            symtab_size = shdr.sh_size;
        } else if (std.mem.eql(u8, sec_name, ".strtab")) {
            strtab_offset = shdr.sh_offset;
            strtab_size = shdr.sh_size;
        }
    }

    if (symtab_size == 0) {
        std.debug.print("elf2mlb: {s}: no .symtab (strip was not run)\n", .{elf_path});
        std.process.exit(1);
    }

    const strtab = elf_data[strtab_offset..][0..strtab_size];
    const sym_count = symtab_size / @sizeOf(elf.Elf32_Sym);

    // Build MLb content in an in-memory buffer.
    var mlb_buf: std.ArrayListUnmanaged(u8) = .empty;
    defer mlb_buf.deinit(alloc);

    var count: usize = 0;
    for (0..sym_count) |i| {
        const sym = readVal(elf.Elf32_Sym, elf_data, symtab_offset + i * @sizeOf(elf.Elf32_Sym));

        if (sym.st_shndx == elf.SHN_UNDEF or sym.st_shndx == elf.SHN_ABS) continue;
        if (sym.st_type() == elf.STT_SECTION or sym.st_type() == elf.STT_FILE) continue;

        const name = std.mem.sliceTo(strtab[sym.st_name..], 0);
        if (isInternal(name)) continue;

        const entry = mlbEntry(sym.st_value) orelse continue;
        const line = try std.fmt.allocPrint(alloc, "{s}:{x}:{s}\n", .{ entry.prefix, entry.offset, name });
        defer alloc.free(line);
        try mlb_buf.appendSlice(alloc, line);
        count += 1;
    }

    // Write MLb file via the new Io API.
    const mlb_file = try cwd.createFile(io, mlb_path, .{});
    defer mlb_file.close(io);
    var write_buf: [4096]u8 = undefined;
    var fw = mlb_file.writer(io, &write_buf);
    try fw.interface.writeAll(mlb_buf.items);
    try fw.flush();

    std.debug.print("elf2mlb: {d} labels -> {s}\n", .{ count, mlb_path });
}
