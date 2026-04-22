// Converts a MOS ELF (with .symtab) to a Mesen label file (.mlb).
// Usage: elf2mlb <binary> <output.mlb> <output.elf>
//   <binary>     - path to the NES binary in the build cache
//                  (the ELF is the sibling file with ".elf" appended)
//   <output.mlb> - destination for the Mesen label file
//   <output.elf> - destination to copy the debug ELF

const std = @import("std");

const STT_NOTYPE: u8 = 0;
const STT_OBJECT: u8 = 1;
const STT_FUNC: u8 = 2;
const STT_SECTION: u8 = 3;
const STT_FILE: u8 = 4;

const SHN_UNDEF: u16 = 0x0000;
const SHN_ABS: u16 = 0xfff1;

const Elf32Ehdr = extern struct {
    e_ident: [16]u8,
    e_type: u16,
    e_machine: u16,
    e_version: u32,
    e_entry: u32,
    e_phoff: u32,
    e_shoff: u32,
    e_flags: u32,
    e_ehsize: u16,
    e_phentsize: u16,
    e_phnum: u16,
    e_shentsize: u16,
    e_shnum: u16,
    e_shstrndx: u16,
};

const Elf32Shdr = extern struct {
    sh_name: u32,
    sh_type: u32,
    sh_flags: u32,
    sh_addr: u32,
    sh_offset: u32,
    sh_size: u32,
    sh_link: u32,
    sh_info: u32,
    sh_addralign: u32,
    sh_entsize: u32,
};

const Elf32Sym = extern struct {
    st_name: u32,
    st_value: u32,
    st_size: u32,
    st_info: u8,
    st_other: u8,
    st_shndx: u16,
};

// Mesen MLb address-type prefix for the NES CPU address space.
fn mlbPrefix(addr: u32) ?[]const u8 {
    return switch (addr) {
        0x0000...0x00ff => "G", // Zero page
        0x0100...0x1fff => "R", // Work RAM
        0x6000...0x7fff => "S", // Save/battery RAM
        0x8000...0xffff => "P", // PRG ROM
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

    var iter = init.minimal.args.iterate();
    _ = iter.next(); // skip argv[0]

    const bin_path = iter.next() orelse usageExit();
    const mlb_path = iter.next() orelse usageExit();
    const elf_out_path = iter.next() orelse usageExit();

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

    if (elf_data.len < @sizeOf(Elf32Ehdr)) {
        std.debug.print("elf2mlb: {s}: file too small\n", .{elf_path});
        std.process.exit(1);
    }

    const ehdr = readVal(Elf32Ehdr, elf_data, 0);
    if (!std.mem.eql(u8, ehdr.e_ident[0..4], "\x7fELF") or ehdr.e_ident[4] != 1) {
        std.debug.print("elf2mlb: {s}: not a 32-bit ELF\n", .{elf_path});
        std.process.exit(1);
    }

    // Section name string table.
    const shstrtab_off = ehdr.e_shoff + @as(u32, ehdr.e_shstrndx) * ehdr.e_shentsize;
    const shstrtab_hdr = readVal(Elf32Shdr, elf_data, shstrtab_off);
    const shstrtab = elf_data[shstrtab_hdr.sh_offset..][0..shstrtab_hdr.sh_size];

    // Find .symtab and .strtab.
    var symtab_offset: u32 = 0;
    var symtab_size: u32 = 0;
    var strtab_offset: u32 = 0;
    var strtab_size: u32 = 0;

    for (0..ehdr.e_shnum) |i| {
        const off = ehdr.e_shoff + @as(u32, @intCast(i)) * ehdr.e_shentsize;
        const shdr = readVal(Elf32Shdr, elf_data, off);
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
    const sym_count = symtab_size / @sizeOf(Elf32Sym);

    // Build MLb content in an in-memory buffer.
    var mlb_buf: std.ArrayList(u8) = .empty;
    defer mlb_buf.deinit(alloc);

    var count: usize = 0;
    for (0..sym_count) |i| {
        const sym = readVal(Elf32Sym, elf_data, symtab_offset + i * @sizeOf(Elf32Sym));

        if (sym.st_shndx == SHN_UNDEF or sym.st_shndx == SHN_ABS) continue;
        const stype = sym.st_info & 0xf;
        if (stype == STT_SECTION or stype == STT_FILE) continue;

        const name = std.mem.sliceTo(strtab[sym.st_name..], 0);
        if (isInternal(name)) continue;

        const prefix = mlbPrefix(sym.st_value) orelse continue;
        const line = try std.fmt.allocPrint(alloc, "{s}:{x:0>4}:{s}\n", .{ prefix, sym.st_value, name });
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
