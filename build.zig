// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");
const sdk_mod = @import("sdk/build.zig");

const SdkLibs = struct {
    sim: ?sdk_mod.Libs = null,
    mega65: ?sdk_mod.Libs = null,
    c64: ?sdk_mod.Libs = null,
    nes: ?sdk_mod.Libs = null,
    neo6502: ?sdk_mod.Libs = null,
    atari2600: ?sdk_mod.Libs = null,
    atari8dos: ?sdk_mod.Libs = null,
    cx16: ?sdk_mod.Libs = null,
    lynxbll: ?sdk_mod.Libs = null,
    pce: ?sdk_mod.Libs = null,
    nes_cnrom: ?sdk_mod.Libs = null,
    nes_unrom: ?sdk_mod.Libs = null,
    nes_mmc1: ?sdk_mod.Libs = null,
    nes_mmc3: ?sdk_mod.Libs = null,
    nes_gtrom: ?sdk_mod.Libs = null,
    nes_unrom_512: ?sdk_mod.Libs = null,
    a2600_3e: ?sdk_mod.Libs = null,
    a8cart: ?sdk_mod.Libs = null,
    snes: ?sdk_mod.Libs = null,
    geos_cbm: ?sdk_mod.Libs = null,
    nes_action53: ?sdk_mod.Libs = null,
    fds: ?sdk_mod.Libs = null,
    vic20: ?sdk_mod.Libs = null,
    atari5200: ?sdk_mod.Libs = null,
    a8megacart: ?sdk_mod.Libs = null,
    a8xegs: ?sdk_mod.Libs = null,
    eater: ?sdk_mod.Libs = null,
    c128: ?sdk_mod.Libs = null,
    pet: ?sdk_mod.Libs = null,
    supervision: ?sdk_mod.Libs = null,
    dodo: ?sdk_mod.Libs = null,
};

pub fn build(b: *std.Build) void {
    // llvm-mos-sdk git source — always required for headers, linker scripts, and platform libs.
    const sdk_dep = b.dependency("llvm-mos-sdk", .{});
    const sdk_src_raw = sdk_dep.path(".").getPath(b);
    const apple2_dep = b.dependency("apple2", .{});
    // Normalize separators for embedding in linker scripts and assembly (.incbin).
    const sdk_src = blk: {
        const buf = b.allocator.dupe(u8, sdk_src_raw) catch @panic("OOM");
        std.mem.replaceScalar(u8, buf, '\\', '/');
        break :blk buf;
    };

    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimize mode for target platform executables (default: ReleaseFast)") orelse .ReleaseFast;

    // ---- SDK build from source (llvm-mos-sdk git) ----
    const sdk_step = b.step("sdk-build", "Build llvm-mos-sdk platform libraries from source");

    var sdk_libs = SdkLibs{};

    for ([_]sdk_mod.Platform{
        .{ .name = "sim", .query = .{ .cpu_arch = .mos, .os_tag = .sim } },
        .{ .name = "mega65", .query = .{ .cpu_arch = .mos, .os_tag = .mega65 } },
        .{ .name = "c64", .query = .{ .cpu_arch = .mos, .os_tag = .c64 } },
        .{ .name = "nes", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "neo6502", .query = .{ .cpu_arch = .mos, .os_tag = .rp6502 } },
        .{ .name = "atari2600-4k", .query = .{ .cpu_arch = .mos, .os_tag = .atari2600 } },
        .{ .name = "atari8-dos", .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
        .{ .name = "cx16", .query = .{ .cpu_arch = .mos, .os_tag = .cx16 } },
        .{ .name = "lynx-bll", .query = .{ .cpu_arch = .mos, .os_tag = .lynx } },
        .{ .name = "pce", .query = .{ .cpu_arch = .mos, .os_tag = .pce } },
        .{ .name = "nes-cnrom", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-unrom", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-mmc1", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-mmc3", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-gtrom", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-unrom-512", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "atari2600-3e", .query = .{ .cpu_arch = .mos, .os_tag = .atari2600 } },
        .{ .name = "atari8-cart-std", .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
        .{ .name = "snes", .query = .{ .cpu_arch = .mos, .os_tag = .snes } },
        .{ .name = "geos-cbm", .query = .{ .cpu_arch = .mos, .os_tag = .geos_cbm } },
        .{ .name = "nes-action53", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "fds", .query = .{ .cpu_arch = .mos, .os_tag = .fds } },
        .{ .name = "vic20", .query = .{ .cpu_arch = .mos, .os_tag = .vic20 } },
        .{ .name = "atari5200-supercart", .query = .{ .cpu_arch = .mos, .os_tag = .atari5200 } },
        .{ .name = "atari8-cart-megacart", .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
        .{ .name = "atari8-cart-xegs", .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
        .{ .name = "eater", .query = .{ .cpu_arch = .mos, .os_tag = .eater } },
        .{ .name = "c128", .query = .{ .cpu_arch = .mos, .os_tag = .c128 } },
        .{ .name = "pet", .query = .{ .cpu_arch = .mos, .os_tag = .pet } },
        .{ .name = "supervision", .query = .{ .cpu_arch = .mos, .os_tag = .supervision } },
        .{ .name = "dodo", .query = .{ .cpu_arch = .mos, .os_tag = .dodo, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos65c02 } } },
    }) |pd| {
        const libs = sdk_mod.buildPlatform(b, sdk_src_raw, pd, optimize);
        const dest = b.fmt("mos-platform/{s}/lib", .{pd.name});
        for ([3]*std.Build.Step.Compile{ libs.crt, libs.crt0, libs.c }) |lib| {
            sdk_step.dependOn(&b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        }
        if (libs.neslib) |l| sdk_step.dependOn(&b.addInstallArtifact(l, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        if (libs.nesdoug) |l| sdk_step.dependOn(&b.addInstallArtifact(l, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        if (libs.nes_c) |l| sdk_step.dependOn(&b.addInstallArtifact(l, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        if (libs.nes_c_startup) |l| sdk_step.dependOn(&b.addInstallArtifact(l, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        if (std.mem.eql(u8, pd.name, "sim")) sdk_libs.sim = libs;
        if (std.mem.eql(u8, pd.name, "mega65")) sdk_libs.mega65 = libs;
        if (std.mem.eql(u8, pd.name, "c64")) sdk_libs.c64 = libs;
        if (std.mem.eql(u8, pd.name, "nes")) sdk_libs.nes = libs;
        if (std.mem.eql(u8, pd.name, "neo6502")) sdk_libs.neo6502 = libs;
        if (std.mem.eql(u8, pd.name, "atari2600-4k")) sdk_libs.atari2600 = libs;
        if (std.mem.eql(u8, pd.name, "atari8-dos")) sdk_libs.atari8dos = libs;
        if (std.mem.eql(u8, pd.name, "cx16")) sdk_libs.cx16 = libs;
        if (std.mem.eql(u8, pd.name, "lynx-bll")) sdk_libs.lynxbll = libs;
        if (std.mem.eql(u8, pd.name, "pce")) sdk_libs.pce = libs;
        if (std.mem.eql(u8, pd.name, "nes-cnrom")) sdk_libs.nes_cnrom = libs;
        if (std.mem.eql(u8, pd.name, "nes-unrom")) sdk_libs.nes_unrom = libs;
        if (std.mem.eql(u8, pd.name, "nes-mmc1")) sdk_libs.nes_mmc1 = libs;
        if (std.mem.eql(u8, pd.name, "nes-mmc3")) sdk_libs.nes_mmc3 = libs;
        if (std.mem.eql(u8, pd.name, "nes-gtrom")) sdk_libs.nes_gtrom = libs;
        if (std.mem.eql(u8, pd.name, "nes-unrom-512")) sdk_libs.nes_unrom_512 = libs;
        if (std.mem.eql(u8, pd.name, "atari2600-3e")) sdk_libs.a2600_3e = libs;
        if (std.mem.eql(u8, pd.name, "atari8-cart-std")) sdk_libs.a8cart = libs;
        if (std.mem.eql(u8, pd.name, "snes")) sdk_libs.snes = libs;
        if (std.mem.eql(u8, pd.name, "geos-cbm")) sdk_libs.geos_cbm = libs;
        if (std.mem.eql(u8, pd.name, "nes-action53")) sdk_libs.nes_action53 = libs;
        if (std.mem.eql(u8, pd.name, "fds")) sdk_libs.fds = libs;
        if (std.mem.eql(u8, pd.name, "vic20")) sdk_libs.vic20 = libs;
        if (std.mem.eql(u8, pd.name, "atari5200-supercart")) sdk_libs.atari5200 = libs;
        if (std.mem.eql(u8, pd.name, "atari8-cart-megacart")) sdk_libs.a8megacart = libs;
        if (std.mem.eql(u8, pd.name, "atari8-cart-xegs")) sdk_libs.a8xegs = libs;
        if (std.mem.eql(u8, pd.name, "eater")) sdk_libs.eater = libs;
        if (std.mem.eql(u8, pd.name, "c128")) sdk_libs.c128 = libs;
        if (std.mem.eql(u8, pd.name, "pet")) sdk_libs.pet = libs;
        if (std.mem.eql(u8, pd.name, "supervision")) sdk_libs.supervision = libs;
        if (std.mem.eql(u8, pd.name, "dodo")) sdk_libs.dodo = libs;
    }

    // Translate neslib.h and nesdoug.h from the MOS SDK into Zig modules.
    const nes_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .nes });
    const neslib_mod = nesHeaderMod(b, sdk_dep, nes_target, "neslib", optimize);
    const nesdoug_mod = nesHeaderMod(b, sdk_dep, nes_target, "nesdoug", optimize);

    // Translate mapper headers for NES banked-ROM platforms.
    const nes_cnrom_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-cnrom", optimize);
    const nes_unrom_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-unrom", optimize);
    const nes_mmc1_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-mmc1", optimize);
    const nes_mmc3_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-mmc3", optimize);
    const nes_gtrom_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-gtrom", optimize);
    const nes_unrom_512_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-unrom-512", optimize);
    const nes_action53_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-action53", optimize);

    // Translate mega65.h into a Zig module.
    const mega65_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .mega65 });
    const mega65_mod = mega65HeaderMod(b, sdk_dep, mega65_target, optimize);

    // Translated headers for CX16.
    const cx16_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .cx16 });
    const cx16_mod = cx16HeaderMod(b, sdk_dep, cx16_target, optimize);
    const cbm_mod = cbmHeaderMod(b, sdk_dep, cx16_target, optimize);

    // Translated headers for VIC-20 (mos6502, separate from cx16/mosw65c02).
    const vic20_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .vic20 });
    const cbm_vic20_mod = vic20CbmHeaderMod(b, sdk_dep, vic20_target, optimize);

    // Translated headers for C128.
    const c128_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c128 });
    const cbm_c128_mod = c128CbmHeaderMod(b, sdk_dep, c128_target, optimize);

    // Translated headers for PET.
    const pet_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .pet });
    const cbm_pet_mod = petCbmHeaderMod(b, sdk_dep, pet_target, optimize);

    // Translated Dodo API headers.
    const dodo_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .dodo, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos65c02 } });
    const dodo_api_mod = dodoApiMod(b, sdk_dep, dodo_target, optimize);

    // Translated headers for C64.
    const c64_build_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 });
    const c64_mod = c64HeaderMod(b, sdk_dep, c64_build_target, optimize);

    // Translated headers for Lynx.
    const lynx_build_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .lynx });
    const lynx_mod = lynxHeaderMod(b, sdk_dep, lynx_build_target, optimize);

    // Translated headers for Sim.
    const sim_build_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .sim });
    const sim_io_mod = simIoHeaderMod(b, sdk_dep, sim_build_target, optimize);

    // Translated GTIA headers for Atari 8-bit.
    const atari8_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari8 });
    const atari8_gtia_mod = atari8GtiaHeaderMod(b, sdk_dep, atari8_target, optimize);

    // Translated PCE headers for PC Engine.
    const pce_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .pce });
    const pce_mod = pceHeaderMod(b, sdk_dep, pce_target, optimize);

    // Host tool: converts MOS ELF symbol tables to Mesen label files (.mlb).
    const elf2mlb = b.addExecutable(.{
        .name = "elf2mlb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/elf2mlb.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(elf2mlb);

    // Host tool: multi-format binary inspector (NES/PRG/A26/XEX/NEO).
    const bininfo = b.addExecutable(.{
        .name = "bininfo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/bininfo.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(bininfo);
    const check_outputs = b.step("check-outputs", "Inspect all built example binaries with bininfo");
    const run_bininfo = b.addRunArtifact(bininfo);
    check_outputs.dependOn(&run_bininfo.step);

    // Host tool: NES CHR ROM → SVG tile-sheet renderer.
    const chr2svg = b.addExecutable(.{
        .name = "chr2svg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/chr2svg.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(chr2svg);

    // Host tool: structural validator for chr2svg-produced SVG files.
    const svgcheck = b.addExecutable(.{
        .name = "svgcheck",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/svgcheck.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(svgcheck);

    // Host tool: SVG tile sheet → NES CHR binary (reverse of chr2svg).
    const svg2chr = b.addExecutable(.{
        .name = "svg2chr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/svg2chr.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(svg2chr);

    // Host tool: NES / SNES pack · unpack · disassemble.
    const romtool = b.addExecutable(.{
        .name = "romtool",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/romtool.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
        }),
    });
    b.installArtifact(romtool);
    const romtool_step = b.step("romtool", "Build romtool (NES/SNES/PRG pack·unpack·disasm)");
    romtool_step.dependOn(&romtool.step);

    // Host tool: 6502 simulator built from llvm-mos-sdk source (no prebuilt binary needed).
    const mos_sim = b.addExecutable(.{
        .name = "mos-sim",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .optimize = .ReleaseSafe,
            .link_libc = true,
            .sanitize_c = .off,
        }),
    });
    mos_sim.root_module.addCSourceFiles(.{
        .root = sdk_dep.path("utils/sim"),
        .files = &.{ "mos-sim.c", "fake6502.c" },
    });
    b.installArtifact(mos_sim);
    const build_mos_sim_step = b.step("build-mos-sim", "Build mos-sim 6502 simulator from source");
    build_mos_sim_step.dependOn(&b.addInstallArtifact(mos_sim, .{}).step);

    // gen-previews: convert each NES example's CHR ROM to an SVG tile sheet.
    const gen_previews = b.step("gen-previews", "Render NES CHR tile data to SVG previews (zig-out/bin/*.chr.svg)");
    const run_svgcheck = b.addRunArtifact(svgcheck);
    gen_previews.dependOn(&run_svgcheck.step);

    for ([_]struct { name: []const u8, chr: []const u8 }{
        .{ .name = "hello1", .chr = "nes/nesdoug/hello1/Alpha.chr" },
        .{ .name = "hello2", .chr = "nes/nesdoug/hello2/Alpha.chr" },
        .{ .name = "hello3", .chr = "nes/nesdoug/hello3/Alpha.chr" },
        .{ .name = "zig-logo", .chr = "nes/nesdoug/zig-logo/zig-mark.chr" },
        .{ .name = "fade", .chr = "nes/nesdoug/fade/Girl5.chr" },
        .{ .name = "sprites", .chr = "nes/nesdoug/sprites/Alpha2.chr" },
        .{ .name = "pads", .chr = "nes/nesdoug/pads/Alpha3.chr" },
        .{ .name = "color-cycle", .chr = "nes/nesdoug/color-cycle/blocks.chr" },
        .{ .name = "bat-ball", .chr = "nes/nesdoug/bat-ball/example.chr" },
        .{ .name = "fullbg", .chr = "nes/nesdoug/fullbg/Girl5.chr" },
        .{ .name = "megablast", .chr = "nes/nesdoug/megablast/megablast.chr" },
        .{ .name = "gg-demo", .chr = "nes/nesdoug/gg-demo/GG-8K.chr" },
        .{ .name = "mappers-apples", .chr = "nes/nesdoug/mappers/apples.chr" },
        .{ .name = "mappers-balls", .chr = "nes/nesdoug/mappers/balls.chr" },
        .{ .name = "mappers-snake", .chr = "nes/nesdoug/mappers/snake.chr" },
        .{ .name = "mappers-flower", .chr = "nes/nesdoug/mappers/flower.chr" },
    }) |cf| {
        const run = b.addRunArtifact(chr2svg);
        run.addFileArg(b.path(cf.chr));
        const out_name = b.fmt("{s}.chr.svg", .{cf.name});
        const svg_out = run.addOutputFileArg(out_name);
        const install_svg = b.addInstallBinFile(svg_out, out_name);
        gen_previews.dependOn(&install_svg.step);
        run_svgcheck.addFileArg(svg_out);
    }

    const gen_labels = b.step("gen-labels", "Generate Mesen label files (.mlb) and install debug ELFs");

    // ---- NES hello1 ----
    {
        const step = b.step("nes-hello1", "Build NES hello1 example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "hello1", "nes/nesdoug/hello1/hello1.zig", .{ .chr_src = "nes/nesdoug/hello1/Alpha.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello1.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "hello1");
    }

    // ---- NES hello2 ----
    {
        const step = b.step("nes-hello2", "Build NES hello2 example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "hello2", "nes/nesdoug/hello2/hello2.zig", .{ .chr_src = "nes/nesdoug/hello2/Alpha.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello2.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "hello2");
    }

    // ---- NES hello3 ----
    {
        const step = b.step("nes-hello3", "Build NES hello3 example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "hello3", "nes/nesdoug/hello3/hello3.zig", .{ .chr_src = "nes/nesdoug/hello3/Alpha.chr", .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello3.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "hello3");
    }

    // ---- NES zig-logo ----
    {
        const step = b.step("nes-zig-logo", "Build NES Zig logo display example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "zig-logo", "nes/nesdoug/zig-logo/zig-logo.zig", .{ .chr_src = "nes/nesdoug/zig-logo/zig-mark.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "zig-logo.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "zig-logo");
    }

    // ---- NES fade ----
    {
        const step = b.step("nes-fade", "Build NES palette fade example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "fade", "nes/nesdoug/fade/fade.zig", .{ .chr_src = "nes/nesdoug/fade/Girl5.chr", .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fade.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "fade");
    }

    // ---- NES fullbg ----
    {
        const step = b.step("nes-fullbg", "Build NES full-screen background (RLE nametable) example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "fullbg", "nes/nesdoug/fullbg/fullbg.zig", .{ .chr_src = "nes/nesdoug/fullbg/Girl5.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fullbg.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "fullbg");
    }

    // ---- NES sprites ----
    {
        const step = b.step("nes-sprites", "Build NES sprites example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "sprites", "nes/nesdoug/sprites/sprites.zig", .{ .chr_src = "nes/nesdoug/sprites/Alpha2.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "sprites.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "sprites");
    }

    // ---- NES random ----
    {
        const step = b.step("nes-random", "Build NES random sprites demo");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "random", "nes/nesdoug/random/random.zig", .{ .chr_src = "nes/nesdoug/random/Alpha2.chr", .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "random.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "random");
    }

    // ---- NES pads ----
    {
        const step = b.step("nes-pads", "Build NES controller input example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "pads", "nes/nesdoug/pads/pads.zig", .{ .chr_src = "nes/nesdoug/pads/Alpha3.chr", .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "pads.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "pads");
    }

    // ---- NES color-cycle ----
    {
        const step = b.step("nes-color-cycle", "Build NES palette colour-cycle example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "color-cycle", "nes/nesdoug/color-cycle/color-cycle.zig", .{ .chr_src = "nes/nesdoug/color-cycle/blocks.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "color-cycle.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "color-cycle");
    }

    // ---- NES bat-ball ----
    {
        const step = b.step("nes-bat-ball", "Build NES bat-ball game (CH05 port)");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "bat-ball", "nes/nesdoug/bat-ball/bat-ball.zig", .{ .chr_src = "nes/nesdoug/bat-ball/example.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "bat-ball.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "bat-ball");
    }

    // ---- NES megablast ----
    {
        const step = b.step("nes-megablast", "Build NES megablast full game (CH13 port: enemies, score, lives, levels)");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "megablast", "nes/nesdoug/megablast/megablast.zig", .{ .chr_src = "nes/nesdoug/megablast/megablast.chr", .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "megablast.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "megablast");
    }

    // ---- NES gg-demo ----
    {
        const step = b.step("nes-gg-demo", "Build NES Game Genie demo (metatile font + scrolling + player)");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "gg-demo", "nes/nesdoug/gg-demo/gg-demo.zig", .{ .chr_src = "nes/nesdoug/gg-demo/GG-8K.chr", .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        exe.root_module.addAssemblyFile(b.path("nes/nesdoug/gg-demo/nesheader.s"));
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "gg-demo.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "gg-demo");
    }

    // ---- C64 hello ----
    {
        const step = b.step("c64-hello", "Build C64 hello example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "c64-hello", "c64/hello/hello.zig", false);
        exe.root_module.addImport("c64", c64_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C64 fibonacci ----
    {
        const step = b.step("c64-fibonacci", "Build C64 fibonacci example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "fibonacci", "c64/fibonacci/fibonacci.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fibonacci.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C64 plasma ----
    {
        const step = b.step("c64-plasma", "Build C64 plasma effect example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), optimize, "plasma", "c64/plasma/plasma.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "plasma.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- GEOS CBM hello ----
    {
        const step = b.step("geos-hello", "Build GEOS CBM hello example");
        const exe = addGeosExe(b, sdk_src, sdk_dep, sdk_libs.geos_cbm orelse @panic("geos-cbm libs not built"), optimize, "geos-hello", "geos/hello/hello.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "geos-hello.cvt" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- MEGA65 (mega65-libc fetched automatically via build.zig.zon) ----
    if (b.lazyDependency("mega65-libc", .{})) |m65_dep| {
        {
            const step = b.step("mega65-hello", "Build MEGA65 hello example");
            const exe = addMega65Exe(b, sdk_dep, sdk_src, sdk_libs.mega65 orelse @panic("mega65 libs not built"), m65_dep, optimize, "mega65-hello", "mega65/hello/hello.zig");
            exe.root_module.addImport("mega65", mega65_mod);
            const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mega65-hello.prg" });
            step.dependOn(&install.step);
            b.getInstallStep().dependOn(&install.step);
            run_bininfo.addFileArg(exe.getEmittedBin());
        }
        {
            const step = b.step("mega65-plasma", "Build MEGA65 plasma example");
            const exe = addMega65Exe(b, sdk_dep, sdk_src, sdk_libs.mega65 orelse @panic("mega65 libs not built"), m65_dep, optimize, "plasma", "mega65/plasma/plasma.zig");
            exe.root_module.addImport("mega65", mega65_mod);
            const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "plasma.prg" });
            step.dependOn(&install.step);
            b.getInstallStep().dependOn(&install.step);
            run_bininfo.addFileArg(exe.getEmittedBin());
        }
        {
            const step = b.step("mega65-viciv", "Build MEGA65 VICIV colour test");
            const exe = addMega65Exe(b, sdk_dep, sdk_src, sdk_libs.mega65 orelse @panic("mega65 libs not built"), m65_dep, optimize, "viciv", "mega65/viciv/viciv.zig");
            const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "viciv.prg" });
            step.dependOn(&install.step);
            b.getInstallStep().dependOn(&install.step);
            run_bininfo.addFileArg(exe.getEmittedBin());
        }
    } else {
        inline for (.{ "mega65-hello", "mega65-plasma", "mega65-viciv" }) |name| {
            _ = b.step(name, "Build MEGA65 example (fetching mega65-libc, re-run to build)");
        }
    }

    // ---- Neo6502 graphics ----
    {
        const neo6502_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .rp6502 });
        const neo6502_mod = neo6502HeaderMod(b, sdk_dep, neo6502_target, optimize);
        const step = b.step("neo6502-graphics", "Build Neo6502 graphics example");
        const exe = addNeo6502Exe(b, sdk_dep, sdk_src, sdk_libs.neo6502 orelse @panic("neo6502 libs not built"), optimize);
        exe.root_module.addImport("neo6502", neo6502_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "graphics.neo" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- sim hello ----
    {
        const step = b.step("sim-hello", "Build mos-sim hello example");
        const exe = addSimExe(b, sdk_dep, sdk_src, sdk_libs.sim orelse @panic("sim libs not built"), optimize, "sim-hello", "sim/hello/hello.zig");
        exe.root_module.addImport("sim_io", sim_io_mod);
        const install = b.addInstallArtifact(exe, .{});
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());

        const run_sim_hello = b.step("run-sim-hello", "Build sim-hello and run it through mos-sim (built from source)");
        const run_cmd = b.addRunArtifact(mos_sim);
        run_cmd.addFileArg(exe.getEmittedBin());
        run_sim_hello.dependOn(&run_cmd.step);
    }

    // ---- Atari 2600 colorbar ----
    {
        const atari2600_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari2600 });
        const vcslib_mod = atari2600HeaderMod(b, sdk_dep, atari2600_target, optimize);
        const step = b.step("atari2600-colorbar", "Build Atari 2600 4K color-bar demo");
        const exe = addAtari2600Exe(b, sdk_dep, sdk_src, sdk_libs.atari2600 orelse @panic("atari2600 libs not built"), optimize, "colorbar", "atari2600/colorbar/colorbar.zig");
        exe.root_module.addImport("vcslib", vcslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "colorbar.a26" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Atari 8-bit DOS hello ----
    {
        const step = b.step("atari8dos-hello", "Build Atari 8-bit DOS hello example");
        const exe = addAtari8DosExe(b, sdk_dep, sdk_src, sdk_libs.atari8dos orelse @panic("atari8dos libs not built"), optimize, "atari8dos-hello", "atari8dos/hello/hello.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "atari8dos-hello.xex" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Apple2 hello ----
    {
        const step = b.step("apple2-hello", "Build Apple IIe hello example");
        const exe = addApple2Exe(b, sdk_src, apple2_dep, optimize);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello.sys" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Commander X16 hello ----
    {
        const step = b.step("cx16-hello", "Build Commander X16 hello example");
        const exe = addCx16Exe(b, sdk_dep, sdk_src, sdk_libs.cx16 orelse @panic("cx16 libs not built"), optimize, "cx16-hello", "cx16/hello/hello.zig");
        exe.root_module.addImport("cbm", cbm_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "cx16-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Commander X16 kernal console test ----
    {
        const step = b.step("cx16-k-console-test", "Build Commander X16 kernal console test");
        const exe = addCx16Exe(b, sdk_dep, sdk_src, sdk_libs.cx16 orelse @panic("cx16 libs not built"), optimize, "cx16-k-console-test", "cx16/k-console-test/k-console-test.zig");
        exe.root_module.addImport("cx16", cx16_mod);
        exe.root_module.addImport("cbm", cbm_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "cx16-k-console-test.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Atari Lynx BLL hello ----
    {
        const step = b.step("lynx-hello", "Build Atari Lynx BLL hello example");
        const exe = addLynxBllExe(b, sdk_dep, sdk_src, sdk_libs.lynxbll orelse @panic("lynx-bll libs not built"), optimize, "lynx-hello", "lynx/hello/hello.zig");
        exe.root_module.addImport("lynx", lynx_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "lynx-hello.bll" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Ben Eater 6502 hello-lcd ----
    {
        const step = b.step("eater-hello-lcd", "Build Ben Eater 6502 LCD hello example");
        const exe = addEaterExe(b, sdk_dep, sdk_src, sdk_libs.eater orelse @panic("eater libs not built"), optimize, "eater-hello-lcd", "eater/hello-lcd/hello-lcd.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "eater-hello-lcd.rom" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
    // ---- Ben Eater 6502 asm-clobber smoke-test ----
    {
        const step = b.step("eater-asm-clobber", "Smoke-test MOS inline-asm clobber declarations (a,x,y,c,v,p,memory)");
        const exe = addEaterExe(b, sdk_dep, sdk_src, sdk_libs.eater orelse @panic("eater libs not built"), optimize, "eater-asm-clobber", "eater/asm-clobber/asm-clobber.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "eater-asm-clobber.rom" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- PC Engine color-cycle ----
    {
        const step = b.step("pce-color-cycle", "Build PC Engine color-cycle example");
        const exe = addPceExe(b, sdk_dep, sdk_src, sdk_libs.pce orelse @panic("pce libs not built"), optimize, "pce-color-cycle", "pce/color-cycle/color-cycle.zig");
        exe.root_module.addImport("pce", pce_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "pce-color-cycle.pce" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- PC Engine color-cycle banked ----
    {
        const step = b.step("pce-color-cycle-banked", "Build PC Engine banked color-cycle example");
        const exe = addPceExe(b, sdk_dep, sdk_src, sdk_libs.pce orelse @panic("pce libs not built"), optimize, "pce-color-cycle-banked", "pce/color-cycle-banked/color-cycle-banked.zig");
        exe.root_module.addImport("pce", pce_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "pce-color-cycle-banked.pce" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES CNROM hello ----
    {
        const step = b.step("nes-cnrom-hello", "Build NES CNROM mapper hello example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "cnrom-hello", "nes/cnrom-hello/cnrom-hello.zig", .{ .mapper = .cnrom, .chr_src = "nes/nesdoug/hello1/Alpha.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_cnrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "cnrom-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES CNROM mappers demo (4 CHR banks) ----
    {
        const step = b.step("nes-mappers", "Build NES CNROM CHR bank-switching demo (4 banks)");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "mappers", "nes/nesdoug/mappers/mappers.zig", .{ .mapper = .cnrom, .chr_srcs = &.{
            "nes/nesdoug/mappers/apples.chr",
            "nes/nesdoug/mappers/balls.chr",
            "nes/nesdoug/mappers/snake.chr",
            "nes/nesdoug/mappers/flower.chr",
        }, .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        exe.root_module.addImport("mapper", nes_cnrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mappers.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES UNROM hello ----
    {
        const step = b.step("nes-unrom-hello", "Build NES UNROM mapper hello example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "unrom-hello", "nes/unrom-hello/unrom-hello.zig", .{ .mapper = .unrom });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_unrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "unrom-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES UNROM-512 hello ----
    {
        const step = b.step("nes-unrom-512-hello", "Build NES UNROM-512 mapper hello example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "unrom-512-hello", "nes/unrom-512-hello/unrom-512-hello.zig", .{ .mapper = .unrom512 });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_unrom_512_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "unrom-512-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES MMC1 hello ----
    {
        const step = b.step("nes-mmc1-hello", "Build NES MMC1 mapper hello example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "mmc1-hello", "nes/mmc1-hello/mmc1-hello.zig", .{ .mapper = .mmc1 });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_mmc1_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mmc1-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES GTROM hello ----
    {
        const step = b.step("nes-gtrom-hello", "Build NES GTROM mapper hello example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "gtrom-hello", "nes/gtrom-hello/gtrom-hello.zig", .{ .mapper = .gtrom });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_gtrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "gtrom-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES MMC3 hello ----
    {
        const step = b.step("nes-mmc3-hello", "Build NES MMC3 mapper hello example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "mmc3-hello", "nes/mmc3-hello/mmc3-hello.zig", .{ .mapper = .mmc3 });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_mmc3_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mmc3-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES CNROM sprites ----
    {
        const step = b.step("nes-cnrom-sprites", "Build NES CNROM mapper sprites example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "cnrom-sprites", "nes/cnrom-sprites/cnrom-sprites.zig", .{ .mapper = .cnrom, .chr_src = "nes/nesdoug/sprites/Alpha2.chr" });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_cnrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "cnrom-sprites.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES UNROM colour-cycle ----
    {
        const step = b.step("nes-unrom-color-cycle", "Build NES UNROM mapper colour-cycle example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "unrom-color-cycle", "nes/unrom-color-cycle/unrom-color-cycle.zig", .{ .mapper = .unrom });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_unrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "unrom-color-cycle.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES MMC1 sprites ----
    {
        const step = b.step("nes-mmc1-sprites", "Build NES MMC1 mapper sprites example (CHR RAM upload)");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "mmc1-sprites", "nes/mmc1-sprites/mmc1-sprites.zig", .{ .mapper = .mmc1 });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_mmc1_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mmc1-sprites.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES MMC3 pads (controller + collision) ----
    {
        const step = b.step("nes-mmc3-pads", "Build NES MMC3 mapper controller+collision example (CHR RAM upload)");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "mmc3-pads", "nes/mmc3-pads/mmc3-pads.zig", .{ .mapper = .mmc3, .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        exe.root_module.addImport("mapper", nes_mmc3_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mmc3-pads.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES GTROM colour-cycle with LED ----
    {
        const step = b.step("nes-gtrom-color-cycle", "Build NES GTROM mapper colour-cycle with LED example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "gtrom-color-cycle", "nes/gtrom-color-cycle/gtrom-color-cycle.zig", .{ .mapper = .gtrom, .with_nesdoug = true });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        exe.root_module.addImport("mapper", nes_gtrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "gtrom-color-cycle.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES Action53 hello ----
    {
        const step = b.step("nes-action53-hello", "Build NES Action53 mapper hello example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs, optimize, "action53-hello", "nes/action53-hello/action53-hello.zig", .{ .mapper = .action53 });
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_action53_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "action53-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- FDS hello ----
    {
        const step = b.step("fds-hello", "Build FDS (Famicom Disk System) hello example");
        const exe = addFdsExe(b, sdk_dep, sdk_src, sdk_libs.fds orelse @panic("fds libs not built"), optimize, "fds-hello", "fds/hello/hello.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fds-hello.fds" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- VIC-20 hello ----
    {
        const step = b.step("vic20-hello", "Build VIC-20 hello example");
        const exe = addVic20Exe(b, sdk_dep, sdk_src, sdk_libs.vic20 orelse @panic("vic20 libs not built"), optimize, "vic20-hello", "vic20/hello/hello.zig");
        exe.root_module.addImport("cbm", cbm_vic20_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "vic20-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C128 hello ----
    {
        const step = b.step("c128-hello", "Build Commodore 128 hello example");
        const exe = addC128Exe(b, sdk_dep, sdk_src, sdk_libs.c128 orelse @panic("c128 libs not built"), optimize, "c128-hello", "c128/hello/hello.zig");
        exe.root_module.addImport("cbm", cbm_c128_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c128-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- PET hello ----
    {
        const step = b.step("pet-hello", "Build Commodore PET hello example");
        const exe = addPetExe(b, sdk_dep, sdk_src, sdk_libs.pet orelse @panic("pet libs not built"), optimize, "pet-hello", "pet/hello/hello.zig");
        exe.root_module.addImport("cbm", cbm_pet_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "pet-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Supervision hello ----
    {
        const step = b.step("supervision-hello", "Build Watara Supervision hello example");
        const exe = addSupervisionExe(b, sdk_dep, sdk_src, sdk_libs.supervision orelse @panic("supervision libs not built"), optimize, "supervision-hello", "supervision/hello/hello.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "supervision-hello.sv" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Dodo hello ----
    {
        const step = b.step("dodo-hello", "Build Dodo hello example");
        const exe = addDodoExe(b, sdk_dep, sdk_src, sdk_libs.dodo orelse @panic("dodo libs not built"), optimize, "dodo-hello", "dodo/hello/hello.zig");
        exe.root_module.addImport("dodo", dodo_api_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "dodo-hello" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Atari 2600 3E colorbar ----
    {
        const atari2600_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari2600 });
        const vcslib_mod_3e = atari2600HeaderMod(b, sdk_dep, atari2600_target, optimize);
        const step = b.step("atari2600-3e-colorbar", "Build Atari 2600 3E mapper color-bar demo");
        const exe = addAtari2600_3eExe(b, sdk_dep, sdk_src, sdk_libs.a2600_3e orelse @panic("atari2600-3e libs not built"), optimize, "colorbar-3e", "atari2600/colorbar-3e/colorbar-3e.zig");
        exe.root_module.addImport("vcslib", vcslib_mod_3e);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "colorbar-3e.a26" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- SNES LoROM hello ----
    {
        const step = b.step("snes-hello", "Build SNES LoROM hello example");
        const exe = addSnesExe(b, sdk_src, sdk_libs.snes orelse @panic("snes libs not built"), optimize, "snes-hello", "snes/hello/hello.zig", .{ .title = "ZIG SNES HELLO" });
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "snes-hello.sfc" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- SNES LoROM colour-cycle ----
    {
        const step = b.step("snes-color-cycle", "Build SNES backdrop colour-cycle demo");
        const exe = addSnesExe(b, sdk_src, sdk_libs.snes orelse @panic("snes libs not built"), optimize, "snes-color-cycle", "snes/color-cycle/color-cycle.zig", .{ .title = "ZIG COLOR CYCLE" });
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "snes-color-cycle.sfc" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- SNES Zig-mark logo ----
    {
        const step = b.step("snes-zig-logo", "Build SNES Zig-mark logo with shimmer animation");
        const exe = addSnesExe(b, sdk_src, sdk_libs.snes orelse @panic("snes libs not built"), optimize, "snes-zig-logo", "snes/zig-logo/zig-logo.zig", .{ .title = "ZIG SNES LOGO" });
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "snes-zig-logo.sfc" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- SNES pi_test ----
    {
        const step = b.step("snes-pi-test", "Build SNES pi demo: compute ~900 digits of π with Spigot algorithm");
        const exe = addSnesExe(b, sdk_src, sdk_libs.snes orelse @panic("snes libs not built"), optimize, "snes-pi-test", "snes/pi-snes/pi-snes.zig", .{ .title = "ZIG PI DEMO" });
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "snes-pi-test.sfc" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- SNES pi FastROM ----
    {
        const step = b.step("snes-pi-fastrom", "Build SNES pi demo as FastROM (header $30, MEMSEL=1, ROM at $80:8000)");
        const exe = addSnesExe(b, sdk_src, sdk_libs.snes orelse @panic("snes libs not built"), optimize, "snes-pi-fastrom", "snes/pi-snes/pi-snes.zig", .{ .fastrom = true, .title = "ZIG PI FASTROM" });
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "snes-pi-fastrom.sfc" });
        step.dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- SNES HiROM hello ----
    {
        const step = b.step("snes-hirom-hello", "Build SNES HiROM hello example");
        const exe = addSnesExe(b, sdk_src, sdk_libs.snes orelse @panic("snes libs not built"), optimize, "snes-hirom-hello", "snes/hirom-hello/hirom-hello.zig", .{ .hirom = true, .title = "ZIG HIROM HELLO" });
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "snes-hirom-hello.sfc" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- SNES pads: controller input + buttonMask demo ----
    {
        const step = b.step("snes-pads", "Build SNES joypad demo: d-pad cycles backdrop color, A+B resets");
        const exe = addSnesExe(b, sdk_src, sdk_libs.snes orelse @panic("snes libs not built"), optimize, "snes-pads", "snes/pads/pads.zig", .{ .title = "SNES PADS DEMO" });
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "snes-pads.sfc" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Atari 8-bit cartridge hello ----
    {
        const step = b.step("atari8-cart-hello", "Build Atari 8-bit standard cartridge hello example");
        const exe = addAtari8SimpleCartExe(b, sdk_dep, sdk_src, sdk_libs.a8cart orelse @panic("atari8-cart libs not built"), optimize, "atari8-cart-hello", "atari8/cart-hello/cart-hello.zig", "atari8-cart-std");
        exe.root_module.addImport("gtia", atari8_gtia_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "atari8-cart-hello.rom" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Atari 5200 supercart color-cycle ----
    {
        const step = b.step("atari5200-cart-hello", "Build Atari 5200 supercart color-cycle demo");
        const exe = addAtari5200Exe(b, sdk_dep, sdk_src, sdk_libs.atari5200 orelse @panic("atari5200 libs not built"), optimize, "atari5200-cart-hello", "atari5200/cart-hello/cart-hello.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "atari5200-cart-hello.rom" });
        step.dependOn(&install.step);
        sdk_step.dependOn(&install.step);
    }

    // ---- Atari 8-bit MegaCart color-cycle ----
    {
        const step = b.step("atari8-megacart-hello", "Build Atari 8-bit MegaCart color-cycle demo");
        const exe = addAtari8CartMegacartExe(b, sdk_dep, sdk_src, sdk_libs.a8megacart orelse @panic("atari8-megacart libs not built"), optimize, "atari8-megacart-hello", "atari8/cart-megacart/cart-megacart.zig");
        exe.root_module.addImport("gtia", atari8_gtia_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "atari8-megacart-hello.rom" });
        step.dependOn(&install.step);
        sdk_step.dependOn(&install.step);
    }

    // ---- Atari 8-bit XEGS color-cycle ----
    {
        const step = b.step("atari8-xegs-hello", "Build Atari 8-bit XEGS cartridge color-cycle demo");
        const exe = addAtari8SimpleCartExe(b, sdk_dep, sdk_src, sdk_libs.a8xegs orelse @panic("atari8-xegs libs not built"), optimize, "atari8-xegs-hello", "atari8/cart-xegs/cart-xegs.zig", "atari8-cart-xegs");
        exe.root_module.addImport("gtia", atari8_gtia_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "atari8-xegs-hello.rom" });
        step.dependOn(&install.step);
        sdk_step.dependOn(&install.step);
    }
}

fn pceHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = b.path("pce/pce.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/pce-common/libpce/include"));
    tc.addIncludePath(sdk_dep.path("mos-platform/pce-common"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn atari2600HeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/atari2600-common/vcslib.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/atari2600-common"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn neo6502HeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/neo6502/api/neo/api.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/neo6502/api"));
    tc.addIncludePath(sdk_dep.path("mos-platform/neo6502/api/neo"));
    tc.addIncludePath(sdk_dep.path("mos-platform/neo6502"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn mega65HeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/mega65/mega65.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/mega65"));
    tc.addIncludePath(sdk_dep.path("mos-platform/c64"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn nesHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    header_name: []const u8,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path(b.fmt("mos-platform/nes/{s}/{s}.h", .{ header_name, header_name })),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path(b.fmt("mos-platform/nes/{s}", .{header_name})));
    tc.addIncludePath(sdk_dep.path("mos-platform/nes/famitone2"));
    tc.addIncludePath(sdk_dep.path("mos-platform/nes"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn addNesLabels(
    b: *std.Build,
    elf2mlb: *std.Build.Step.Compile,
    gen_labels: *std.Build.Step,
    exe: *std.Build.Step.Compile,
    name: []const u8,
) void {
    const run = b.addRunArtifact(elf2mlb);
    run.addFileArg(exe.getEmittedBin());
    const mlb_name = b.fmt("{s}.nes.mlb", .{name});
    const elf_name = b.fmt("{s}.nes.elf", .{name});
    const mlb_out = run.addOutputFileArg(mlb_name);
    const elf_out = run.addOutputFileArg(elf_name);
    const install_mlb = b.addInstallBinFile(mlb_out, mlb_name);
    const install_elf = b.addInstallBinFile(elf_out, elf_name);
    gen_labels.dependOn(&install_mlb.step);
    gen_labels.dependOn(&install_elf.step);
}

const NesMapper = enum {
    nrom,
    cnrom,
    unrom,
    unrom512,
    mmc1,
    mmc3,
    gtrom,
    action53,
};

fn addNesExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    sdk_libs: SdkLibs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
    cfg: struct {
        mapper: NesMapper = .nrom,
        chr_src: ?[]const u8 = null,
        chr_srcs: ?[]const []const u8 = null,
        with_nesdoug: bool = false,
    },
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .nes });

    const libs: sdk_mod.Libs = switch (cfg.mapper) {
        .nrom => sdk_libs.nes orelse @panic("nes libs not built"),
        .cnrom => sdk_libs.nes_cnrom orelse @panic("nes-cnrom libs not built"),
        .unrom => sdk_libs.nes_unrom orelse @panic("nes-unrom libs not built"),
        .unrom512 => sdk_libs.nes_unrom_512 orelse @panic("nes-unrom-512 libs not built"),
        .mmc1 => sdk_libs.nes_mmc1 orelse @panic("nes-mmc1 libs not built"),
        .mmc3 => sdk_libs.nes_mmc3 orelse @panic("nes-mmc3 libs not built"),
        .gtrom => sdk_libs.nes_gtrom orelse @panic("nes-gtrom libs not built"),
        .action53 => sdk_libs.nes_action53 orelse @panic("nes-action53 libs not built"),
    };

    const plat: []const u8 = switch (cfg.mapper) {
        .nrom => "nes-nrom",
        .cnrom => "nes-cnrom",
        .unrom => "nes-unrom",
        .unrom512 => "nes-unrom-512",
        .mmc1 => "nes-mmc1",
        .mmc3 => "nes-mmc3",
        .gtrom => "nes-gtrom",
        .action53 => "nes-action53",
    };

    // Mappers that require a separately-compiled reset.o TRUE object (linker INPUT directive).
    const needs_reset = switch (cfg.mapper) {
        .nrom, .cnrom => false,
        .unrom, .unrom512, .mmc1, .mmc3, .gtrom, .action53 => true,
    };
    const reset_dir = if (needs_reset) b.fmt("{s}/objs/{s}", .{ b.install_path, name }) else "";
    var install_reset: ?*std.Build.Step.InstallFile = null;
    if (needs_reset) {
        const reset_asm = if (cfg.mapper == .mmc3)
            b.fmt("mos-platform/{s}/reset-banked-8.s", .{plat})
        else
            b.fmt("mos-platform/{s}/reset.s", .{plat});
        const reset_obj_name = if (cfg.mapper == .mmc3) "reset-banked-8.o" else "reset.o";
        const reset_obj_stem = if (cfg.mapper == .mmc3) "reset-banked-8" else "reset";
        const reset_obj = b.addObject(.{
            .name = reset_obj_stem,
            .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }),
        });
        reset_obj.root_module.addAssemblyFile(sdk_dep.path(reset_asm));
        install_reset = b.addInstallFileWithDir(
            reset_obj.getEmittedBin(),
            .{ .custom = b.fmt("objs/{s}", .{name}) },
            reset_obj_name,
        );
    }

    // Wrapper linker script: SEARCH_DIRs + optional symbol overrides + INCLUDE.
    const wf = b.addWriteFiles();
    const ld_name = b.fmt("{s}-wrapper.ld", .{plat});
    const wrapper_ld = switch (cfg.mapper) {
        .nrom => wf.add(ld_name, b.fmt(
            \\SEARCH_DIR("{s}/mos-platform/nes-nrom");
            \\SEARCH_DIR("{s}/mos-platform/nes");
            \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
            \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
            \\INCLUDE "{s}/mos-platform/nes-nrom/link.ld"
        , .{ sdk_src, sdk_src, sdk_src, sdk_src, sdk_src })),
        .cnrom => blk: {
            const chr_kb: usize = if (cfg.chr_srcs) |s| s.len * 8 else 8;
            break :blk wf.add(ld_name, b.fmt(
                \\SEARCH_DIR("{s}/mos-platform/nes-cnrom");
                \\SEARCH_DIR("{s}/mos-platform/nes");
                \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
                \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
                \\/* One or more 8 KiB CHR bank(s); override the 2048 KiB weak default. */
                \\__chr_rom_size = {d};
                \\INCLUDE "{s}/mos-platform/nes-cnrom/link.ld"
            , .{ sdk_src, sdk_src, sdk_src, sdk_src, chr_kb, sdk_src }));
        },
        .unrom => wf.add(ld_name, b.fmt(
            \\SEARCH_DIR("{s}");
            \\SEARCH_DIR("{s}/mos-platform/nes-unrom");
            \\SEARCH_DIR("{s}/mos-platform/nes");
            \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
            \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
            \\/* UNROM uses CHR RAM, not CHR ROM; override the 8 KiB CHR ROM weak default. */
            \\__chr_rom_size = 0;
            \\__chr_ram_size = 8;
            \\INCLUDE "{s}/mos-platform/nes-unrom/link.ld"
        , .{ reset_dir, sdk_src, sdk_src, sdk_src, sdk_src, sdk_src })),
        .unrom512 => wf.add(ld_name, b.fmt(
            \\SEARCH_DIR("{s}");
            \\SEARCH_DIR("{s}/mos-platform/nes-unrom-512");
            \\SEARCH_DIR("{s}/mos-platform/nes");
            \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
            \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
            \\/* UNROM-512 uses CHR RAM (32 KiB); zero out CHR ROM default. */
            \\__chr_rom_size = 0;
            \\__chr_ram_size = 32;
            \\INCLUDE "{s}/mos-platform/nes-unrom-512/link.ld"
        , .{ reset_dir, sdk_src, sdk_src, sdk_src, sdk_src, sdk_src })),
        .mmc1 => wf.add(ld_name, b.fmt(
            \\SEARCH_DIR("{s}");
            \\SEARCH_DIR("{s}/mos-platform/nes-mmc1");
            \\SEARCH_DIR("{s}/mos-platform/nes");
            \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
            \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
            \\/* MMC1 hello uses CHR RAM; override the 128 KiB CHR ROM weak default. */
            \\__chr_rom_size = 0;
            \\__chr_ram_size = 8;
            \\INCLUDE "{s}/mos-platform/nes-mmc1/link.ld"
        , .{ reset_dir, sdk_src, sdk_src, sdk_src, sdk_src, sdk_src })),
        .mmc3 => wf.add(ld_name, b.fmt(
            \\SEARCH_DIR("{s}");
            \\SEARCH_DIR("{s}/mos-platform/nes-mmc3");
            \\SEARCH_DIR("{s}/mos-platform/nes");
            \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
            \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
            \\/* MMC3 hello uses CHR RAM; override the 256 KiB CHR ROM weak default. */
            \\__chr_rom_size = 0;
            \\__chr_ram_size = 8;
            \\INCLUDE "{s}/mos-platform/nes-mmc3/link.ld"
        , .{ reset_dir, sdk_src, sdk_src, sdk_src, sdk_src, sdk_src })),
        .gtrom => wf.add(ld_name, b.fmt(
            \\SEARCH_DIR("{s}");
            \\SEARCH_DIR("{s}/mos-platform/nes-gtrom");
            \\SEARCH_DIR("{s}/mos-platform/nes");
            \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
            \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
            \\INCLUDE "{s}/mos-platform/nes-gtrom/link.ld"
        , .{ reset_dir, sdk_src, sdk_src, sdk_src, sdk_src, sdk_src })),
        .action53 => wf.add(ld_name, b.fmt(
            \\SEARCH_DIR("{s}");
            \\SEARCH_DIR("{s}/mos-platform/nes-action53");
            \\SEARCH_DIR("{s}/mos-platform/nes");
            \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
            \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
            \\/* Action53 uses CHR RAM; override the 8 KiB CHR ROM weak default. */
            \\__chr_rom_size = 0;
            \\__chr_ram_size = 8;
            \\INCLUDE "{s}/mos-platform/nes-action53/link.ld"
        , .{ reset_dir, sdk_src, sdk_src, sdk_src, sdk_src, sdk_src })),
    };

    // CHR ROM assembly (NROM/CNROM only).
    const root_fwd = blk: {
        const p = b.build_root.path orelse ".";
        const buf = b.allocator.dupe(u8, p) catch @panic("OOM");
        std.mem.replaceScalar(u8, buf, '\\', '/');
        break :blk buf;
    };
    var chr_asm: ?std.Build.LazyPath = null;
    if (cfg.chr_srcs) |srcs| {
        const parts = b.allocator.alloc([]const u8, srcs.len) catch @panic("OOM");
        for (srcs, 0..) |src, i| {
            parts[i] = b.fmt(
                \\.section .chr_rom_{d},"a",@progbits
                \\.incbin "{s}/{s}"
                \\
            , .{ i, root_fwd, src });
        }
        const content = std.mem.concat(b.allocator, u8, parts) catch @panic("OOM");
        const chr_wf = b.addWriteFiles();
        chr_asm = chr_wf.add("chr-rom-abs.s", content);
    } else if (cfg.chr_src) |src| {
        const chr_wf = b.addWriteFiles();
        chr_asm = chr_wf.add("chr-rom-abs.s", b.fmt(
            \\.section .chr_rom,"a",@progbits
            \\.incbin "{s}/{s}"
        , .{ root_fwd, src }));
    }

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    if (install_reset) |ir| exe.step.dependOn(&ir.step);
    // crt0.S must be a direct object (no exported symbol → linker won't pull from archive).
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/common/crt0/crt0.S"));
    // sdk/mem.s strong __memset overrides the weak recursive stub.
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    if (chr_asm) |ca| exe.root_module.addAssemblyFile(ca);
    // Variant ines.s: sets mapper number and default CHR/PRG ROM sizes.
    exe.root_module.addAssemblyFile(sdk_dep.path(b.fmt("mos-platform/{s}/ines.s", .{plat})));
    // Common nes/ines.s: NES 2.0 weak defaults for ram/nvram/chr-ram/misc fields.
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/ines.s"));
    // rompoke: weak default for __rom_poke_table_size.
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/rompoke/rompoke.s"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.neslib) |neslib| exe.root_module.linkLibrary(neslib);
    if (cfg.with_nesdoug) if (libs.nesdoug) |nd| exe.root_module.linkLibrary(nd);
    if (libs.nes_c) |nc| exe.root_module.linkLibrary(nc);
    if (libs.nes_c_startup) |ncs| exe.root_module.linkLibrary(ncs);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addC64Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
    with_printf_flt: bool,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 });

    const wf = b.addWriteFiles();
    const libc_txt = addLibcTxt(b, wf, sdk_src, "c64");
    // Inline c64/link.ld + commodore/commodore.ld, replacing INPUT() directives with
    // addAssemblyFile calls below (lld INPUT() doesn't search -L paths for .o files).
    const wrapper_ld = wf.add("c64-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/c64");
        \\SEARCH_DIR("{s}/mos-platform/commodore");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\__basic_zp_start = 0x0002;
        \\__basic_zp_end = 0x0090;
        \\MEMORY {{ ram (rw) : ORIGIN = 0x0801, LENGTH = 0xC7FF }}
        \\__rc0 = __basic_zp_start;
        \\INCLUDE "imag-regs.ld"
        \\__basic_zp_size = __basic_zp_end - __basic_zp_start;
        \\MEMORY {{ zp : ORIGIN = __rc31 + 1, LENGTH = __basic_zp_end - (__rc31 + 1) }}
        \\REGION_ALIAS("c_readonly", ram)
        \\REGION_ALIAS("c_writeable", ram)
        \\SECTIONS {{ .basic_header : {{ *(.basic_header) }} INCLUDE "c.ld" }}
        \\__stack = 0xD000;
        \\OUTPUT_FORMAT {{ SHORT(ORIGIN(ram)) TRIM(ram) }}
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    // basic-header.S and unmap-basic.S replace INPUT(basic-header.o) / INPUT(unmap-basic.o).
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c64/basic-header.S"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c64/unmap-basic.S"));
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.printf) |libprintf| exe.root_module.linkLibrary(libprintf);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    if (with_printf_flt) exe.root_module.linkSystemLibrary("printf_flt", .{ .use_pkg_config = .no });
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addMega65Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    m65_dep: *std.Build.Dependency,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .mega65 });

    const wf = b.addWriteFiles();
    const libc_txt = addLibcTxt(b, wf, sdk_src, "mega65");
    // Inline mega65/link.ld + commodore/commodore.ld, replacing INPUT() directives with
    // addAssemblyFile calls below.
    const wrapper_ld = wf.add("mega65-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/mega65");
        \\SEARCH_DIR("{s}/mos-platform/c64");
        \\SEARCH_DIR("{s}/mos-platform/commodore");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\__basic_zp_start = 0x0002;
        \\__basic_zp_end = 0x0090;
        \\MEMORY {{ ram (rw) : ORIGIN = 0x2001, LENGTH = 0xafff }}
        \\__rc0 = __basic_zp_start;
        \\INCLUDE "imag-regs.ld"
        \\__basic_zp_size = __basic_zp_end - __basic_zp_start;
        \\MEMORY {{ zp : ORIGIN = __rc31 + 1, LENGTH = __basic_zp_end - (__rc31 + 1) }}
        \\REGION_ALIAS("c_readonly", ram)
        \\REGION_ALIAS("c_writeable", ram)
        \\SECTIONS {{ .basic_header : {{ *(.basic_header) }} INCLUDE "c.ld" }}
        \\__stack = 0xd000;
        \\OUTPUT_FORMAT {{ SHORT(0x2001) TRIM(ram) }}
    , .{ sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    // basic-header.S and unmap-basic.S replace INPUT(basic-header.o) / INPUT(unmap-basic.o).
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/mega65/basic-header.S"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/mega65/unmap-basic.S"));
    exe.root_module.addAssemblyFile(b.path("mega65/memory_asm.s"));
    exe.root_module.addIncludePath(m65_dep.path("include"));
    exe.root_module.addIncludePath(m65_dep.path("include/mega65"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addNeo6502Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .rp6502 });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/neo6502/api/neo\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/neo6502\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));
    const wrapper_ld = wf.add("neo6502-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/neo6502");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/neo6502/link.ld"
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = "graphics",
        .root_module = b.createModule(.{
            .root_source_file = b.path("neo6502/graphics.zig"),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    if (libs.mem) |obj| exe.root_module.addObject(obj);
    addMosPanicImport(b, exe, target, opt);
    _ = sdk_dep;

    return exe;
}

fn addSimExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .sim });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("sim-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/sim");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/sim/link.ld"
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    // LTO DCE eliminates both mosCallMainSection and mosMain because:
    // - mosCallMainSection: nothing in bitcode calls it (only linker KEEP, which runs after LTO)
    // - mosMain: referenced only via inline-asm "jsr main" which LTO doesn't trace
    // Both exported aliases must be forced-undefined to survive the LTO pass.
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);
    _ = sdk_dep;

    return exe;
}

fn addAtari2600Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari2600 });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("atari2600-4k-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/atari2600-common");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/atari2600-4k/link.ld"
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    // atari2600-common/crt0.S is a standalone object (not part of the library).
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/atari2600-common/crt0.S"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/atari2600-common"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addAtari8DosExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari8 });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/atari8-common\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/atari8-dos\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));
    const wrapper_ld = wf.add("atari8-dos-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/atari8-dos");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/atari8-dos/link.ld"
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/atari8-common"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addFdsExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .fds });

    // reset.s → reset.o; link.ld has INPUT(reset.o) requiring SEARCH_DIR.
    const reset_obj = b.addObject(.{
        .name = "reset",
        .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }),
    });
    reset_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/fds/reset.s"));
    const reset_dir = b.fmt("{s}/objs/{s}", .{ b.install_path, name });
    const install_reset = b.addInstallFileWithDir(
        reset_obj.getEmittedBin(),
        .{ .custom = b.fmt("objs/{s}", .{name}) },
        "reset.o",
    );

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("fds-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}");
        \\SEARCH_DIR("{s}/mos-platform/fds");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/fds/link.ld"
    , .{ reset_dir, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.step.dependOn(&install_reset.step);
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/fds"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/nes"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);
    exe.root_module.addImport("hardware", b.createModule(.{
        .root_source_file = b.path("fds/hardware.zig"),
        .target = target,
        .optimize = opt,
        .sanitize_c = .off,
    }));

    return exe;
}

fn addVic20Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .vic20 });

    // basic-header.S → basic-header.o; commodore.ld has INPUT(basic-header.o).
    const basic_header_obj = b.addObject(.{
        .name = "basic-header",
        .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }),
    });
    basic_header_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/asminc"));
    basic_header_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    basic_header_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/vic20/basic-header.S"));
    basic_header_obj.lto = .none;
    const objs_dir = b.fmt("objs/{s}", .{name});
    const install_bh = b.addInstallFileWithDir(
        basic_header_obj.getEmittedBin(),
        .{ .custom = objs_dir },
        "basic-header.o",
    );

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("vic20-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/{s}");
        \\SEARCH_DIR("{s}/mos-platform/vic20");
        \\SEARCH_DIR("{s}/mos-platform/commodore");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/vic20/link.ld"
    , .{ b.install_path, objs_dir, sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.step.dependOn(&install_bh.step);
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/vic20"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addC128Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c128 });

    // basic-header.S and init-mmu.S: section-only TRUE objects installed for INPUT() resolution.
    const basic_header_obj = b.addObject(.{
        .name = "basic-header",
        .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }),
    });
    basic_header_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/asminc"));
    basic_header_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    basic_header_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c128/basic-header.S"));
    basic_header_obj.lto = .none;

    const init_mmu_obj = b.addObject(.{
        .name = "init-mmu",
        .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }),
    });
    init_mmu_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/c128"));
    init_mmu_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/asminc"));
    init_mmu_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    init_mmu_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c128/init-mmu.S"));
    init_mmu_obj.lto = .none;

    const objs_dir = b.fmt("objs/{s}", .{name});
    const install_bh = b.addInstallFileWithDir(basic_header_obj.getEmittedBin(), .{ .custom = objs_dir }, "basic-header.o");
    const install_mmu = b.addInstallFileWithDir(init_mmu_obj.getEmittedBin(), .{ .custom = objs_dir }, "init-mmu.o");

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("c128-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/{s}");
        \\SEARCH_DIR("{s}/mos-platform/c128");
        \\SEARCH_DIR("{s}/mos-platform/commodore");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/c128/link.ld"
    , .{ b.install_path, objs_dir, sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.step.dependOn(&install_bh.step);
    exe.step.dependOn(&install_mmu.step);
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/c128"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/c64"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.printf) |libprintf| exe.root_module.linkLibrary(libprintf);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addPetExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .pet });

    // basic-header.S: section-only TRUE object installed for commodore.ld INPUT(basic-header.o).
    const basic_header_obj = b.addObject(.{
        .name = "basic-header",
        .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }),
    });
    basic_header_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/asminc"));
    basic_header_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    basic_header_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/pet/basic-header.S"));
    basic_header_obj.lto = .none;

    const objs_dir = b.fmt("objs/{s}", .{name});
    const install_bh = b.addInstallFileWithDir(basic_header_obj.getEmittedBin(), .{ .custom = objs_dir }, "basic-header.o");

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("pet-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/{s}");
        \\SEARCH_DIR("{s}/mos-platform/pet");
        \\SEARCH_DIR("{s}/mos-platform/commodore");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/pet/link.ld"
    , .{ b.install_path, objs_dir, sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.step.dependOn(&install_bh.step);
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/pet"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.printf) |libprintf| exe.root_module.linkLibrary(libprintf);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addSupervisionExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .supervision });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("supervision-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/supervision");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/supervision/link.ld"
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    if (libs.crt0_obj2) |obj| exe.root_module.addObject(obj);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/supervision"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addDodoExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .dodo, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos65c02 } });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("dodo-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/dodo");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/dodo/link.ld"
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    if (libs.crt0_obj2) |obj| exe.root_module.addObject(obj);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/dodo"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn c128CbmHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/commodore/cbm.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.defineCMacro("__CBM__", null);
    tc.defineCMacro("__C128__", null);
    tc.addIncludePath(sdk_dep.path("mos-platform/c128"));
    tc.addIncludePath(sdk_dep.path("mos-platform/c64"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn petCbmHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/commodore/cbm.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.defineCMacro("__CBM__", null);
    tc.defineCMacro("__PET__", null);
    tc.addIncludePath(sdk_dep.path("mos-platform/pet"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn dodoApiMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/dodo/api.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/dodo"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn vic20CbmHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/commodore/cbm.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.defineCMacro("__CBM__", null);
    tc.addIncludePath(sdk_dep.path("mos-platform/vic20"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn addCx16Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .cx16 });

    const wf = b.addWriteFiles();
    const libc_txt = addLibcTxt(b, wf, sdk_src, "cx16");
    const wrapper_ld = wf.add("cx16-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/cx16");
        \\SEARCH_DIR("{s}/mos-platform/commodore");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\__basic_zp_start = 0x0002;
        \\__basic_zp_end = 0x0080;
        \\MEMORY {{ ram (rw) : ORIGIN = 0x0801, LENGTH = 0x96FF }}
        \\__rc0 = __basic_zp_start;
        \\INCLUDE "imag-regs.ld"
        \\__basic_zp_size = __basic_zp_end - __basic_zp_start;
        \\MEMORY {{ zp : ORIGIN = __rc31 + 1, LENGTH = __basic_zp_end - (__rc31 + 1) }}
        \\REGION_ALIAS("c_readonly", ram)
        \\REGION_ALIAS("c_writeable", ram)
        \\SECTIONS {{ .basic_header : {{ *(.basic_header) }} INCLUDE "c.ld" }}
        \\__stack = 0x9F00;
        \\OUTPUT_FORMAT {{ SHORT(ORIGIN(ram)) TRIM(ram) }}
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/cx16/basic-header.S"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/cx16"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addLynxBllExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .lynx });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("lynx-bll-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/lynx-bll");
        \\SEARCH_DIR("{s}/mos-platform/lynx");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/lynx-bll/link.ld"
    , .{ sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/lynx"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addEaterExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .eater });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("eater-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/eater");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/eater/link.ld"
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/eater"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addPceExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .pce });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("pce-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/pce");
        \\SEARCH_DIR("{s}/mos-platform/pce-common");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/pce/link.ld"
    , .{ sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    // LTO DCE eliminates mosCallMainSection (in .call_main) because the
    // linker KEEP() reference runs after LTO. Force both symbols to keep
    // the .call_main JSR and the main() function itself.
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    exe.root_module.addCSourceFile(.{
        .file = sdk_dep.path("mos-platform/pce/crt0/crt0.S"),
    });
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/asminc"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/pce-common/libpce/include"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/pce-common"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addAtari2600_3eExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari2600 });

    const init_obj = b.addObject(.{
        .name = "init_mapper_3e",
        .root_module = b.createModule(.{ .target = target, .optimize = opt }),
    });
    init_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/atari2600-3e/init_mapper_3e.S"));
    init_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/atari2600-3e"));
    init_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/atari2600-common"));
    init_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    const init_dir = b.fmt("{s}/objs/{s}", .{ b.install_path, name });
    const install_init = b.addInstallFileWithDir(init_obj.getEmittedBin(), .{ .custom = b.fmt("objs/{s}", .{name}) }, "init_mapper_3e.o");

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("atari2600-3e-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}");
        \\SEARCH_DIR("{s}/mos-platform/atari2600-3e");
        \\SEARCH_DIR("{s}/mos-platform/atari2600-common");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/atari2600-3e/link.ld"
    , .{ init_dir, sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/atari2600-common/crt0.S"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/atari2600-3e"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/atari2600-common"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    exe.step.dependOn(&install_init.step);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addAtari8SimpleCartExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
    cart_plat: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari8 });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/atari8-common\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/{s}\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src, cart_plat },
    ));
    const wrapper_ld = wf.add(b.fmt("{s}-wrapper.ld", .{cart_plat}), b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/{s}");
        \\SEARCH_DIR("{s}/mos-platform/atari8-common");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/{s}/link.ld"
    , .{ sdk_src, cart_plat, sdk_src, sdk_src, sdk_src, cart_plat }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/atari8-common"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addAtari5200Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari5200 });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/common/include\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/atari5200-supercart\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));
    const wrapper_ld = wf.add("atari5200-supercart-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/atari5200-supercart");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/atari5200-supercart/link.ld"
    , .{ sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addAtari8CartMegacartExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari8 });

    // tail0.s → tail0.o TRUE object; megacart link.ld has INPUT(tail0.o).
    const tail0_obj = b.addObject(.{
        .name = "tail0",
        .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }),
    });
    tail0_obj.root_module.addIncludePath(sdk_dep.path("mos-platform/common/asminc"));
    tail0_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/atari8-cart-megacart/tail0.s"));
    tail0_obj.lto = .none;
    const objs_dir = b.fmt("objs/{s}", .{name});
    const install_tail0 = b.addInstallFileWithDir(
        tail0_obj.getEmittedBin(),
        .{ .custom = objs_dir },
        "tail0.o",
    );

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/atari8-common\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/atari8-cart-megacart\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));
    const wrapper_ld = wf.add("atari8-cart-megacart-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/{s}");
        \\SEARCH_DIR("{s}/mos-platform/atari8-cart-megacart");
        \\SEARCH_DIR("{s}/mos-platform/atari8-common");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/atari8-cart-megacart/link.ld"
    , .{ b.install_path, objs_dir, sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.step.dependOn(&install_tail0.step);
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/atari8-common"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);

    return exe;
}

fn addSnesExe(
    b: *std.Build,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
    cfg: struct { lorom: bool = true, fastrom: bool = false, hirom: bool = false, title: ?[]const u8 = null },
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .snes });

    const build_root = b.build_root.path orelse ".";
    const wf = b.addWriteFiles();
    const ld_file = if (cfg.fastrom) "fastrom.ld" else "lorom.ld";
    const ld_wrapper = if (cfg.hirom) "snes-hirom-wrapper.ld" else if (cfg.fastrom) "snes-fastrom-wrapper.ld" else "snes-lorom-wrapper.ld";
    const wrapper_ld = wf.add(ld_wrapper, b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/snes/{s}"
    , .{ sdk_src, build_root, ld_file }));

    // Build ROM header title: pad/truncate to exactly 21 ASCII bytes.
    const raw_title = cfg.title orelse if (cfg.hirom) "ZIG SNES HIROM" else "ZIG SNES HELLO";
    var title_buf: [21]u8 = .{' '} ** 21;
    @memcpy(title_buf[0..@min(raw_title.len, 21)], raw_title[0..@min(raw_title.len, 21)]);
    const map_mode: u8 = if (cfg.hirom) 0x21 else if (cfg.fastrom) 0x30 else 0x20;

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    exe.root_module.addAssemblyFile(b.path("snes/crt0.s"));
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    const snes_mod = b.createModule(.{
        .root_source_file = b.path("snes/hardware.zig"),
        .target = target,
        .optimize = opt,
        .sanitize_c = .off,
    });
    const sneslib_mod = b.createModule(.{
        .root_source_file = b.path("snes/sneslib.zig"),
        .target = target,
        .optimize = opt,
        .sanitize_c = .off,
    });
    sneslib_mod.addImport("snes", snes_mod);
    exe.root_module.addImport("snes", snes_mod);
    exe.root_module.addImport("sneslib", sneslib_mod);
    // Generate SNES ROM header dynamically with the per-exe title.
    const header_src = b.fmt(
        \\// Copyright (c) 2024 Matheus C. França
        \\// SPDX-License-Identifier: Apache-2.0
        \\comptime {{
        \\    asm (
        \\        \\.section .snes_header,"a",@progbits
        \\        \\    .ascii "{s}"
        \\        \\    .byte  0x{x:0>2}
        \\        \\    .byte  0x00
        \\        \\    .byte  0x05
        \\        \\    .byte  0x00
        \\        \\    .byte  0x01
        \\        \\    .byte  0x00
        \\        \\    .byte  0x00
        \\        \\    .word  0xffff
        \\        \\    .word  0x0000
        \\        \\
        \\        \\.extern nmi_handler
        \\        \\.section .vectors,"a",@progbits
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  nmi_handler
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  0x0000
        \\        \\    .word  _start
        \\        \\    .word  0x0000
        \\    );
        \\}}
        \\
    , .{ title_buf, map_mode });
    exe.root_module.addImport("snes_header", b.createModule(.{
        .root_source_file = wf.add("snes_header.zig", header_src),
        .target = target,
        .optimize = opt,
        .sanitize_c = .off,
    }));
    addMosPanicImport(b, exe, target, opt);
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn cx16HeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/cx16/cx16.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/cx16"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn cbmHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/commodore/cbm.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.defineCMacro("__CBM__", null);
    tc.addIncludePath(sdk_dep.path("mos-platform/cx16"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn c64HeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/c64/c64.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/c64"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn lynxHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/lynx/lynx.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/lynx"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn nesMapperHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    platform: []const u8,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path(b.fmt("mos-platform/{s}/mapper.h", .{platform})),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path(b.fmt("mos-platform/{s}", .{platform})));
    tc.addIncludePath(sdk_dep.path("mos-platform/nes"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn atari8GtiaHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/atari8-common/_gtia.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/atari8-common"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn simIoHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/sim/sim-io.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/sim"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn geosHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        // geos_zig.h suppresses _Static_assert (struct-size checks fail during translation)
        .root_source_file = b.path("geos/geos_zig.h"),
        .target = target,
        .optimize = opt,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/geos-cbm"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn addGeosExe(
    b: *std.Build,
    sdk_src: []const u8,
    sdk_dep: *std.Build.Dependency,
    libs: sdk_mod.Libs,
    opt: std.builtin.OptimizeMode,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .geos_cbm });

    const wf = b.addWriteFiles();
    const libc_txt = addLibcTxt(b, wf, sdk_src, "geos-cbm");
    // vlir.ld is the GEOS VLIR linker script (produces .cvt binary via OUTPUT_FORMAT FULL blocks).
    // It includes c.ld (common sections) and geos.ld (GEOS symbol table) via INCLUDE directives,
    // both resolved through the SEARCH_DIRs below.
    const wrapper_ld = wf.add("geos-cbm-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/geos-cbm");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "vlir.ld"
    , .{ sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.forceUndefinedSymbol("__zig_call_main_section");
    exe.forceUndefinedSymbol("main");
    if (libs.crt0_obj) |obj| exe.root_module.addObject(obj);
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.printf) |lib| exe.root_module.linkLibrary(lib);
    if (libs.mem) |mem_obj| exe.root_module.addObject(mem_obj);
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);
    addMosPanicImport(b, exe, target, opt);
    exe.root_module.addImport("geos", geosHeaderMod(b, sdk_dep, target, opt));

    return exe;
}

fn addApple2Exe(
    b: *std.Build,
    sdk_src: []const u8,
    apple2_dep: *std.Build.Dependency,
    opt: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .appleii });
    const apple2_root = apple2_dep.path(".").getPath(b);

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("apple2-hello-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/src/lib/apple-ii-bare/link.ld"
    , .{ sdk_src, apple2_root }));

    const exe = b.addExecutable(.{
        .name = "apple2-hello",
        .root_module = b.createModule(.{
            .root_source_file = b.path("apple2/hello/hello.zig"),
            .target = target,
            .optimize = opt,
            .sanitize_c = .off,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addImport("apple2", b.createModule(.{
        .root_source_file = b.path("apple2/hardware.zig"),
        .target = target,
        .optimize = opt,
        .sanitize_c = .off,
    }));
    addMosPanicImport(b, exe, target, opt);
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/asminc", .{sdk_src}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/crt", .{sdk_src}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/include", .{sdk_src}) });
    // Common crt0: stack init + call_main + zp register declarations.
    exe.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/mos-platform/common/crt0", .{sdk_src}) },
        .files = &.{ "crt0.S", "init-stack.S" },
    });
    // libcrt: compiler runtime builtins (__udivhi3, __mulsi3, __ashlqi3, __set_v, etc.).
    exe.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/mos-platform/common/crt", .{sdk_src}) },
        .files = &.{ "const.S", "call-indir.S", "divmod.cc", "divmod-large.cc", "mul.cc", "shift.cc", "rotate.cc" },
    });
    // mem.c: provides __memset / __memcpy needed by LLVM for bulk-zeroing.
    exe.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/mos-platform/common/c", .{sdk_src}) },
        .files = &.{"mem.c"},
    });
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addMosPanicImport(b: *std.Build, exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, opt: std.builtin.OptimizeMode) void {
    exe.root_module.addImport("mos_panic", b.createModule(.{
        .root_source_file = b.path("sdk/panic.zig"),
        .target = target,
        .optimize = opt,
        .sanitize_c = .off,
    }));
}

fn addLibcTxt(b: *std.Build, wf: *std.Build.Step.WriteFile, sdk_src: []const u8, plat: []const u8) std.Build.LazyPath {
    return wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/{s}\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/{s}\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, plat, sdk_src, sdk_src, plat },
    ));
}
