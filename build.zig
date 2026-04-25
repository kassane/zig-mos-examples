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
    a2600_3e: ?sdk_mod.Libs = null,
    a8cart: ?sdk_mod.Libs = null,
    snes: ?sdk_mod.Libs = null,
};

pub fn build(b: *std.Build) void {
    // llvm-mos-sdk git source — always required for headers, linker scripts, and platform libs.
    const sdk_dep = b.dependency("llvm-mos-sdk", .{});
    const sdk_src_raw = sdk_dep.path(".").getPath(b);
    // Normalize separators for embedding in linker scripts and assembly (.incbin).
    const sdk_src = blk: {
        const buf = b.allocator.dupe(u8, sdk_src_raw) catch @panic("OOM");
        std.mem.replaceScalar(u8, buf, '\\', '/');
        break :blk buf;
    };

    const apple2_sdk = b.option([]const u8, "apple2-sdk", "Path to apple-ii-port-work checkout (required for apple2 examples)");

    // ---- SDK build from source (llvm-mos-sdk git) ----
    const sdk_step = b.step("sdk-build", "Build llvm-mos-sdk platform libraries from source");

    var sdk_libs = SdkLibs{};

    for ([_]sdk_mod.Platform{
        .{ .name = "sim", .query = .{ .cpu_arch = .mos, .os_tag = .sim } },
        .{ .name = "mega65", .query = .{ .cpu_arch = .mos, .os_tag = .mega65 } },
        .{ .name = "c64", .query = .{ .cpu_arch = .mos, .os_tag = .c64 } },
        .{ .name = "nes", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "neo6502", .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 } } },
        .{ .name = "atari2600-4k", .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502x } } },
        .{ .name = "atari8-dos", .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
        .{ .name = "cx16", .query = .{ .cpu_arch = .mos, .os_tag = .cx16 } },
        .{ .name = "lynx-bll", .query = .{ .cpu_arch = .mos, .os_tag = .lynx } },
        .{ .name = "pce", .query = .{ .cpu_arch = .mos, .os_tag = .pce } },
        .{ .name = "nes-cnrom", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-unrom", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-mmc1", .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "atari2600-3e", .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502x } } },
        .{ .name = "atari8-cart-std", .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
        .{ .name = "snes", .query = .{ .cpu_arch = .mos, .os_tag = .snes } },
    }) |pd| {
        const libs = sdk_mod.buildPlatform(b, sdk_src_raw, pd);
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
        if (std.mem.eql(u8, pd.name, "atari2600-3e")) sdk_libs.a2600_3e = libs;
        if (std.mem.eql(u8, pd.name, "atari8-cart-std")) sdk_libs.a8cart = libs;
        if (std.mem.eql(u8, pd.name, "snes")) sdk_libs.snes = libs;
    }

    // Translate neslib.h and nesdoug.h from the MOS SDK into Zig modules.
    const nes_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .nes });
    const neslib_mod = nesHeaderMod(b, sdk_dep, nes_target, "neslib");
    const nesdoug_mod = nesHeaderMod(b, sdk_dep, nes_target, "nesdoug");

    // Translate mapper headers for NES banked-ROM platforms.
    const nes_cnrom_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-cnrom");
    const nes_unrom_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-unrom");
    const nes_mmc1_mapper_mod = nesMapperHeaderMod(b, sdk_dep, nes_target, "nes-mmc1");

    // Translate mega65.h into a Zig module.
    const mega65_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .mega65 });
    const mega65_mod = mega65HeaderMod(b, sdk_dep, mega65_target);

    // Translated headers for CX16.
    const cx16_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .cx16 });
    const cx16_mod = cx16HeaderMod(b, sdk_dep, cx16_target);
    const cbm_mod = cbmHeaderMod(b, sdk_dep, cx16_target);

    // Translated headers for C64.
    const c64_build_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 });
    const c64_mod = c64HeaderMod(b, sdk_dep, c64_build_target);

    // Translated headers for Lynx.
    const lynx_build_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .lynx });
    const lynx_mod = lynxHeaderMod(b, sdk_dep, lynx_build_target);

    // Translated headers for Sim.
    const sim_build_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .sim });
    const sim_io_mod = simIoHeaderMod(b, sdk_dep, sim_build_target);

    // Translated GTIA headers for Atari 8-bit.
    const atari8_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari8 });
    const atari8_gtia_mod = atari8GtiaHeaderMod(b, sdk_dep, atari8_target);

    // Host tool: converts MOS ELF symbol tables to Mesen label files (.mlb).
    const elf2mlb = b.addExecutable(.{
        .name = "elf2mlb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/elf2mlb.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(elf2mlb);

    // Host tool: multi-format binary inspector (NES/PRG/A26/XEX/NEO).
    const bininfo = b.addExecutable(.{
        .name = "bininfo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/bininfo.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
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
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(chr2svg);

    // Host tool: structural validator for chr2svg-produced SVG files.
    const svgcheck = b.addExecutable(.{
        .name = "svgcheck",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/svgcheck.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(svgcheck);

    // Host tool: SVG tile sheet → NES CHR binary (reverse of chr2svg).
    const svg2chr = b.addExecutable(.{
        .name = "svg2chr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/svg2chr.zig"),
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });
    b.installArtifact(svg2chr);

    // Host tool: 6502 simulator built from llvm-mos-sdk source (no prebuilt binary needed).
    const mos_sim = b.addExecutable(.{
        .name = "mos-sim",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .optimize = .ReleaseFast,
            .link_libc = true,
        }),
    });
    mos_sim.root_module.addCSourceFiles(.{
        .root = sdk_dep.path("utils/sim"),
        .files = &.{ "mos-sim.c", "fake6502.c" },
        .flags = &.{},
    });
    b.installArtifact(mos_sim);
    const build_mos_sim_step = b.step("build-mos-sim", "Build mos-sim 6502 simulator from source");
    build_mos_sim_step.dependOn(&b.addInstallArtifact(mos_sim, .{}).step);

    // gen-previews: convert each NES example's CHR ROM to an SVG tile sheet.
    const gen_previews = b.step("gen-previews", "Render NES CHR tile data to SVG previews (zig-out/bin/*.chr.svg)");
    const run_svgcheck = b.addRunArtifact(svgcheck);
    gen_previews.dependOn(&run_svgcheck.step);

    for ([_]struct { name: []const u8, chr: []const u8 }{
        .{ .name = "hello1", .chr = "nesdoug/hello1/Alpha.chr" },
        .{ .name = "hello2", .chr = "nesdoug/hello2/Alpha.chr" },
        .{ .name = "hello3", .chr = "nesdoug/hello3/Alpha.chr" },
        .{ .name = "zig-logo", .chr = "nesdoug/zig-logo/zig-mark.chr" },
        .{ .name = "fade", .chr = "nesdoug/fade/Girl5.chr" },
        .{ .name = "sprites", .chr = "nesdoug/sprites/Alpha2.chr" },
        .{ .name = "pads", .chr = "nesdoug/pads/Alpha3.chr" },
        .{ .name = "color-cycle", .chr = "nesdoug/color-cycle/blocks.chr" },
        .{ .name = "bat-ball", .chr = "nesdoug/sprites/Alpha2.chr" },
    }) |cf| {
        const run = b.addRunArtifact(chr2svg);
        run.addFileArg(b.path(cf.chr));
        const svg_out = run.addOutputFileArg(b.fmt("{s}.chr.svg", .{cf.name}));
        const install_svg = b.addInstallBinFile(svg_out, b.fmt("{s}.chr.svg", .{cf.name}));
        gen_previews.dependOn(&install_svg.step);
        run_svgcheck.addFileArg(svg_out);
    }

    const gen_labels = b.step("gen-labels", "Generate Mesen label files (.mlb) and install debug ELFs");

    // ---- NES hello1 ----
    {
        const step = b.step("nes-hello1", "Build NES hello1 example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "hello1", "nesdoug/hello1/hello1.zig", "nesdoug/hello1/Alpha.chr", false);
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
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "hello2", "nesdoug/hello2/hello2.zig", "nesdoug/hello2/Alpha.chr", false);
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
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "hello3", "nesdoug/hello3/hello3.zig", "nesdoug/hello3/Alpha.chr", true);
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
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "zig-logo", "nesdoug/zig-logo/zig-logo.zig", "nesdoug/zig-logo/zig-mark.chr", false);
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
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "fade", "nesdoug/fade/fade.zig", "nesdoug/fade/Girl5.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fade.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "fade");
    }

    // ---- NES sprites ----
    {
        const step = b.step("nes-sprites", "Build NES sprites example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "sprites", "nesdoug/sprites/sprites.zig", "nesdoug/sprites/Alpha2.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "sprites.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "sprites");
    }

    // ---- NES pads ----
    {
        const step = b.step("nes-pads", "Build NES controller input example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "pads", "nesdoug/pads/pads.zig", "nesdoug/pads/Alpha3.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "pads.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "pads");
    }

    // ---- NES color-cycle ----
    {
        const step = b.step("nes-color-cycle", "Build NES palette colour-cycle example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "color-cycle", "nesdoug/color-cycle/color-cycle.zig", "nesdoug/color-cycle/blocks.chr", false);
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
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_libs.nes orelse @panic("nes libs not built"), "bat-ball", "nesdoug/bat-ball/bat-ball.zig", "nesdoug/sprites/Alpha2.chr", true);
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "bat-ball.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
        addNesLabels(b, elf2mlb, gen_labels, exe, "bat-ball");
    }

    // ---- C64 hello ----
    {
        const step = b.step("c64-hello", "Build C64 hello example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), "c64-hello", "c64/hello/hello.zig", false);
        exe.root_module.addImport("c64", c64_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C64 fibonacci ----
    {
        const step = b.step("c64-fibonacci", "Build C64 fibonacci example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), "fibonacci", "c64/fibonacci/fibonacci.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fibonacci.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- C64 plasma ----
    {
        const step = b.step("c64-plasma", "Build C64 plasma effect example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_libs.c64 orelse @panic("c64 libs not built"), "plasma", "c64/plasma/plasma.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "plasma.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- MEGA65 (mega65-libc fetched automatically via build.zig.zon) ----
    if (b.lazyDependency("mega65-libc", .{})) |m65_dep| {
        {
            const step = b.step("mega65-hello", "Build MEGA65 hello example");
            const exe = addMega65Exe(b, sdk_dep, sdk_src, sdk_libs.mega65 orelse @panic("mega65 libs not built"), m65_dep, "mega65-hello", "mega65/hello/hello.zig");
            exe.root_module.addImport("mega65", mega65_mod);
            const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mega65-hello.prg" });
            step.dependOn(&install.step);
            b.getInstallStep().dependOn(&install.step);
            run_bininfo.addFileArg(exe.getEmittedBin());
        }
        {
            const step = b.step("mega65-plasma", "Build MEGA65 plasma example");
            const exe = addMega65Exe(b, sdk_dep, sdk_src, sdk_libs.mega65 orelse @panic("mega65 libs not built"), m65_dep, "plasma", "mega65/plasma/plasma.zig");
            exe.root_module.addImport("mega65", mega65_mod);
            const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "plasma.prg" });
            step.dependOn(&install.step);
            b.getInstallStep().dependOn(&install.step);
            run_bininfo.addFileArg(exe.getEmittedBin());
        }
        {
            const step = b.step("mega65-viciv", "Build MEGA65 VICIV colour test");
            const exe = addMega65Exe(b, sdk_dep, sdk_src, sdk_libs.mega65 orelse @panic("mega65 libs not built"), m65_dep, "viciv", "mega65/viciv/viciv.zig");
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
        const neo6502_target = b.resolveTargetQuery(.{
            .cpu_arch = .mos,
            .os_tag = .freestanding,
            .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 },
        });
        const neo6502_mod = neo6502HeaderMod(b, sdk_dep, neo6502_target);
        const step = b.step("neo6502-graphics", "Build Neo6502 graphics example");
        const exe = addNeo6502Exe(b, sdk_dep, sdk_src, sdk_libs.neo6502 orelse @panic("neo6502 libs not built"));
        exe.root_module.addImport("neo6502", neo6502_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "graphics.neo" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- sim hello ----
    {
        const step = b.step("sim-hello", "Build mos-sim hello example");
        const exe = addSimExe(b, sdk_dep, sdk_src, sdk_libs.sim orelse @panic("sim libs not built"), "sim-hello", "sim/hello/hello.zig");
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
        const atari2600_target = b.resolveTargetQuery(.{
            .cpu_arch = .mos,
            .os_tag = .freestanding,
            .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502x },
        });
        const vcslib_mod = atari2600HeaderMod(b, sdk_dep, atari2600_target);
        const step = b.step("atari2600-colorbar", "Build Atari 2600 4K color-bar demo");
        const exe = addAtari2600Exe(b, sdk_dep, sdk_src, sdk_libs.atari2600 orelse @panic("atari2600 libs not built"), "colorbar", "atari2600/colorbar/colorbar.zig");
        exe.root_module.addImport("vcslib", vcslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "colorbar.a26" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Atari 8-bit DOS hello ----
    {
        const step = b.step("atari8dos-hello", "Build Atari 8-bit DOS hello example");
        const exe = addAtari8DosExe(b, sdk_dep, sdk_src, sdk_libs.atari8dos orelse @panic("atari8dos libs not built"), "atari8dos-hello", "atari8dos/hello/hello.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "atari8dos-hello.xex" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Apple2 hello ----
    if (apple2_sdk) |a2_sdk| {
        const step = b.step("apple2-hello", "Build Apple2 hello example");
        const exe = addApple2Exe(b, sdk_dep, sdk_src, a2_sdk);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello.sys" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    } else {
        const step = b.step("apple2-hello", "Build Apple2 hello example (requires -Dapple2-sdk=<path>)");
        _ = step;
        std.log.info("apple2-hello: skipping (pass -Dapple2-sdk=<path> to enable)", .{});
    }

    // ---- Commander X16 hello ----
    {
        const step = b.step("cx16-hello", "Build Commander X16 hello example");
        const exe = addCx16Exe(b, sdk_dep, sdk_src, sdk_libs.cx16 orelse @panic("cx16 libs not built"), "cx16-hello", "cx16/hello/hello.zig");
        exe.root_module.addImport("cbm", cbm_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "cx16-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Commander X16 kernal console test ----
    {
        const step = b.step("cx16-k-console-test", "Build Commander X16 kernal console test");
        const exe = addCx16Exe(b, sdk_dep, sdk_src, sdk_libs.cx16 orelse @panic("cx16 libs not built"), "cx16-k-console-test", "cx16/k-console-test/k-console-test.zig");
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
        const exe = addLynxBllExe(b, sdk_dep, sdk_src, sdk_libs.lynxbll orelse @panic("lynx-bll libs not built"), "lynx-hello", "lynx/hello/hello.zig");
        exe.root_module.addImport("lynx", lynx_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "lynx-hello.bll" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- PC Engine color-cycle ----
    {
        const step = b.step("pce-color-cycle", "Build PC Engine color-cycle example");
        const exe = addPceExe(b, sdk_dep, sdk_src, sdk_libs.pce orelse @panic("pce libs not built"), "pce-color-cycle", "pce/color-cycle/color-cycle.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "pce-color-cycle.pce" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- PC Engine color-cycle banked ----
    {
        const step = b.step("pce-color-cycle-banked", "Build PC Engine banked color-cycle example");
        const exe = addPceExe(b, sdk_dep, sdk_src, sdk_libs.pce orelse @panic("pce libs not built"), "pce-color-cycle-banked", "pce/color-cycle-banked/color-cycle-banked.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "pce-color-cycle-banked.pce" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES CNROM hello ----
    {
        const step = b.step("nes-cnrom-hello", "Build NES CNROM mapper hello example");
        const exe = addNesCnromExe(b, sdk_dep, sdk_src, sdk_libs.nes_cnrom orelse @panic("nes-cnrom libs not built"), "cnrom-hello", "nes/cnrom-hello/cnrom-hello.zig", "nesdoug/hello1/Alpha.chr");
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_cnrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "cnrom-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES UNROM hello ----
    {
        const step = b.step("nes-unrom-hello", "Build NES UNROM mapper hello example");
        const exe = addNesUnromExe(b, sdk_dep, sdk_src, sdk_libs.nes_unrom orelse @panic("nes-unrom libs not built"), "unrom-hello", "nes/unrom-hello/unrom-hello.zig");
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_unrom_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "unrom-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- NES MMC1 hello ----
    {
        const step = b.step("nes-mmc1-hello", "Build NES MMC1 mapper hello example");
        const exe = addNesMmc1Exe(b, sdk_dep, sdk_src, sdk_libs.nes_mmc1 orelse @panic("nes-mmc1 libs not built"), "mmc1-hello", "nes/mmc1-hello/mmc1-hello.zig");
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("mapper", nes_mmc1_mapper_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mmc1-hello.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Atari 2600 3E colorbar ----
    {
        const atari2600_target = b.resolveTargetQuery(.{
            .cpu_arch = .mos,
            .os_tag = .freestanding,
            .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502x },
        });
        const vcslib_mod_3e = atari2600HeaderMod(b, sdk_dep, atari2600_target);
        const step = b.step("atari2600-3e-colorbar", "Build Atari 2600 3E mapper color-bar demo");
        const exe = addAtari2600_3eExe(b, sdk_dep, sdk_src, sdk_libs.a2600_3e orelse @panic("atari2600-3e libs not built"), "colorbar-3e", "atari2600/colorbar-3e/colorbar-3e.zig");
        exe.root_module.addImport("vcslib", vcslib_mod_3e);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "colorbar-3e.a26" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- SNES LoROM hello ----
    {
        const step = b.step("snes-hello", "Build SNES LoROM hello example");
        const exe = addSnesExe(b, sdk_src, sdk_libs.snes orelse @panic("snes libs not built"), "snes-hello", "snes/hello/hello.zig");
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "snes-hello.sfc" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }

    // ---- Atari 8-bit cartridge hello ----
    {
        const step = b.step("atari8-cart-hello", "Build Atari 8-bit standard cartridge hello example");
        const exe = addAtari8CartStdExe(b, sdk_dep, sdk_src, sdk_libs.a8cart orelse @panic("atari8-cart libs not built"), "atari8-cart-hello", "atari8/cart-hello/cart-hello.zig");
        exe.root_module.addImport("gtia", atari8_gtia_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "atari8-cart-hello.rom" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        run_bininfo.addFileArg(exe.getEmittedBin());
    }
}

fn atari2600HeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/atari2600-common/vcslib.h"),
        .target = target,
        .optimize = .ReleaseFast,
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
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/neo6502/api/neo/api.h"),
        .target = target,
        .optimize = .ReleaseFast,
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
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/mega65/mega65.h"),
        .target = target,
        .optimize = .ReleaseFast,
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
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path(b.fmt("mos-platform/nes/{s}/{s}.h", .{ header_name, header_name })),
        .target = target,
        .optimize = .ReleaseFast,
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
    const mlb_out = run.addOutputFileArg(b.fmt("{s}.nes.mlb", .{name}));
    const elf_out = run.addOutputFileArg(b.fmt("{s}.nes.elf", .{name}));
    const install_mlb = b.addInstallBinFile(mlb_out, b.fmt("{s}.nes.mlb", .{name}));
    const install_elf = b.addInstallBinFile(elf_out, b.fmt("{s}.nes.elf", .{name}));
    gen_labels.dependOn(&install_mlb.step);
    gen_labels.dependOn(&install_elf.step);
}

fn addNesExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
    chr_src: []const u8,
    with_nesdoug: bool,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 },
    });

    // Wrapper linker script: add SEARCH_DIRs for all .ld include files, then INCLUDE the main script.
    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("nes-nrom-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/nes-nrom");
        \\SEARCH_DIR("{s}/mos-platform/nes");
        \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/nes-nrom/link.ld"
    , .{ sdk_src, sdk_src, sdk_src, sdk_src, sdk_src }));

    const root_fwd = blk: {
        const p = b.build_root.path orelse ".";
        const buf = b.allocator.dupe(u8, p) catch @panic("OOM");
        std.mem.replaceScalar(u8, buf, '\\', '/');
        break :blk buf;
    };
    const chr_wf = b.addWriteFiles();
    const chr_asm = chr_wf.add("chr-rom-abs.s", b.fmt(
        \\.section .chr_rom,"a",@progbits
        \\.incbin "{s}/{s}"
    , .{ root_fwd, chr_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    // crt0.S provides .call_main (jsr main) — must be a direct object, not an
    // archive member, because it defines no symbols so the linker won't extract it.
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/common/crt0/crt0.S"));
    exe.root_module.addAssemblyFile(chr_asm);
    // iNES header symbols (nes-nrom mapper, chr/prg rom size defaults).
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes-nrom/ines.s"));
    // iNES 2.0 weak defaults for ram/nvram/chr-ram sizes and misc header fields.
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/ines.s"));
    // rompoke: weak default for __rom_poke_table_size.
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/rompoke/rompoke.s"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.neslib) |neslib| exe.root_module.linkLibrary(neslib);
    if (with_nesdoug) if (libs.nesdoug) |nesdoug| exe.root_module.linkLibrary(nesdoug);
    if (libs.nes_c) |nc| exe.root_module.linkLibrary(nc);
    if (libs.nes_c_startup) |ncs| exe.root_module.linkLibrary(ncs);
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addC64Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
    with_printf_flt: bool,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .c64 });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/c64\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/c64\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));
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
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    // basic-header.S and unmap-basic.S replace INPUT(basic-header.o) / INPUT(unmap-basic.o).
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c64/basic-header.S"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/c64/unmap-basic.S"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (with_printf_flt) exe.root_module.linkSystemLibrary("printf_flt", .{ .use_pkg_config = .no });
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addMega65Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    m65_dep: *std.Build.Dependency,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .mega65 });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/mega65\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/mega65\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));
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
            .optimize = .ReleaseFast,
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

    return exe;
}

fn addNeo6502Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 },
    });

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
            .optimize = .ReleaseFast,
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
    _ = sdk_dep;

    return exe;
}

fn addSimExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
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
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    _ = sdk_dep;

    return exe;
}

fn addAtari2600Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502x },
    });

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
            .optimize = .ReleaseFast,
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

    return exe;
}

fn addAtari8DosExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
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
            .optimize = .ReleaseFast,
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

    return exe;
}

fn addCx16Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .cx16, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 } });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/cx16\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/cx16\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));
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
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
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

    return exe;
}

fn addLynxBllExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .lynx, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 } });

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
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/lynx"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addPceExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .pce, .cpu_model = .{ .explicit = &std.Target.mos.cpu.moshuc6280 } });

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
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    // crt0/crt0.S is a standalone object — needs huc6280 cpu and access to common/asminc/imag.inc.
    exe.root_module.addCSourceFile(.{
        .file = sdk_dep.path("mos-platform/pce/crt0/crt0.S"),
        .flags = &.{"-mcpu=moshuc6280"},
    });
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/asminc"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/pce-common/libpce/include"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/pce-common"));
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addNesCnromExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
    chr_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 },
    });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("nes-cnrom-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/nes-cnrom");
        \\SEARCH_DIR("{s}/mos-platform/nes");
        \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\/* One 8 KiB CHR bank (Alpha.chr); override the 2048 KiB weak default. */
        \\__chr_rom_size = 8;
        \\INCLUDE "{s}/mos-platform/nes-cnrom/link.ld"
    , .{ sdk_src, sdk_src, sdk_src, sdk_src, sdk_src }));

    const root_fwd = blk: {
        const p = b.build_root.path orelse ".";
        const buf = b.allocator.dupe(u8, p) catch @panic("OOM");
        std.mem.replaceScalar(u8, buf, '\\', '/');
        break :blk buf;
    };
    const chr_wf = b.addWriteFiles();
    const chr_asm = chr_wf.add("chr-rom-abs.s", b.fmt(
        \\.section .chr_rom,"a",@progbits
        \\.incbin "{s}/{s}"
    , .{ root_fwd, chr_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/common/crt0/crt0.S"));
    exe.root_module.addAssemblyFile(chr_asm);
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes-cnrom/ines.s"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/ines.s"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/rompoke/rompoke.s"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.neslib) |neslib| exe.root_module.linkLibrary(neslib);
    if (libs.nesdoug) |nesdoug| exe.root_module.linkLibrary(nesdoug);
    if (libs.nes_c) |nc| exe.root_module.linkLibrary(nc);
    if (libs.nes_c_startup) |ncs| exe.root_module.linkLibrary(ncs);
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addNesUnromExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 },
    });

    // Pre-build reset.s as a separate object so the linker script's INPUT(reset.o)
    // can resolve via SEARCH_DIR. We install the .o to a dedicated subdir inside
    // the install prefix so the linker can find it.
    const reset_obj = b.addObject(.{
        .name = "reset",
        .root_module = b.createModule(.{ .target = target, .optimize = .ReleaseFast }),
    });
    reset_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes-unrom/reset.s"));
    const reset_dir = b.fmt("{s}/objs/{s}", .{ b.install_path, name });
    const install_reset = b.addInstallFileWithDir(reset_obj.getEmittedBin(), .{ .custom = b.fmt("objs/{s}", .{name}) }, "reset.o");

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("nes-unrom-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}");
        \\SEARCH_DIR("{s}/mos-platform/nes-unrom");
        \\SEARCH_DIR("{s}/mos-platform/nes");
        \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\/* UNROM uses CHR RAM, not CHR ROM; override the 8 KiB CHR ROM weak default. */
        \\__chr_rom_size = 0;
        \\__chr_ram_size = 8;
        \\INCLUDE "{s}/mos-platform/nes-unrom/link.ld"
    , .{ reset_dir, sdk_src, sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/common/crt0/crt0.S"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes-unrom/ines.s"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/ines.s"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/rompoke/rompoke.s"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.neslib) |neslib| exe.root_module.linkLibrary(neslib);
    if (libs.nesdoug) |nesdoug| exe.root_module.linkLibrary(nesdoug);
    if (libs.nes_c) |nc| exe.root_module.linkLibrary(nc);
    if (libs.nes_c_startup) |ncs| exe.root_module.linkLibrary(ncs);
    exe.setLinkerScript(wrapper_ld);
    exe.step.dependOn(&install_reset.step);

    return exe;
}

fn addNesMmc1Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 },
    });

    const reset_obj = b.addObject(.{
        .name = "reset",
        .root_module = b.createModule(.{ .target = target, .optimize = .ReleaseFast }),
    });
    reset_obj.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes-mmc1/reset.s"));
    const reset_dir = b.fmt("{s}/objs/{s}", .{ b.install_path, name });
    const install_reset = b.addInstallFileWithDir(reset_obj.getEmittedBin(), .{ .custom = b.fmt("objs/{s}", .{name}) }, "reset.o");

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("nes-mmc1-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}");
        \\SEARCH_DIR("{s}/mos-platform/nes-mmc1");
        \\SEARCH_DIR("{s}/mos-platform/nes");
        \\SEARCH_DIR("{s}/mos-platform/nes/rompoke");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\/* MMC1 hello uses CHR RAM; override the 128 KiB CHR ROM weak default. */
        \\__chr_rom_size = 0;
        \\__chr_ram_size = 8;
        \\INCLUDE "{s}/mos-platform/nes-mmc1/link.ld"
    , .{ reset_dir, sdk_src, sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/common/crt0/crt0.S"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes-mmc1/ines.s"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes-mmc1/init-prg-ram-0.s"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/ines.s"));
    exe.root_module.addAssemblyFile(sdk_dep.path("mos-platform/nes/rompoke/rompoke.s"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    if (libs.neslib) |neslib| exe.root_module.linkLibrary(neslib);
    if (libs.nesdoug) |nesdoug| exe.root_module.linkLibrary(nesdoug);
    if (libs.nes_c) |nc| exe.root_module.linkLibrary(nc);
    if (libs.nes_c_startup) |ncs| exe.root_module.linkLibrary(ncs);
    exe.setLinkerScript(wrapper_ld);
    exe.step.dependOn(&install_reset.step);

    return exe;
}

fn addAtari2600_3eExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502x },
    });

    const init_obj = b.addObject(.{
        .name = "init_mapper_3e",
        .root_module = b.createModule(.{ .target = target, .optimize = .ReleaseFast }),
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
            .optimize = .ReleaseFast,
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

    return exe;
}

fn addAtari8CartStdExe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .atari8 });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/atari8-common\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/atari8-cart-std\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));
    const wrapper_ld = wf.add("atari8-cart-std-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/atari8-cart-std");
        \\SEARCH_DIR("{s}/mos-platform/atari8-common");
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/mos-platform/atari8-cart-std/link.ld"
    , .{ sdk_src, sdk_src, sdk_src, sdk_src }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = .ReleaseFast,
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

    return exe;
}

fn addSnesExe(
    b: *std.Build,
    sdk_src: []const u8,
    libs: sdk_mod.Libs,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .snes });

    const build_root = b.build_root.path orelse ".";
    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("snes-lorom-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/common/ldscripts");
        \\INCLUDE "{s}/snes/lorom.ld"
    , .{ sdk_src, build_root }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    const opt = exe.root_module.optimize.?;
    exe.root_module.addImport("snes", b.createModule(.{
        .root_source_file = b.path("snes/hardware.zig"),
        .target = target,
        .optimize = opt,
    }));
    exe.root_module.addImport("crt0", b.createModule(.{
        .root_source_file = b.path("snes/crt0.zig"),
        .target = target,
        .optimize = opt,
    }));
    exe.root_module.addImport("snes_header", b.createModule(.{
        .root_source_file = b.path("snes/header.zig"),
        .target = target,
        .optimize = opt,
    }));
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
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/cx16/cx16.h"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = false,
    });
    tc.defineCMacro("__CX16__", null);
    tc.addIncludePath(sdk_dep.path("mos-platform/cx16"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn cbmHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/commodore/cbm.h"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = false,
    });
    tc.defineCMacro("__CBM__", null);
    tc.defineCMacro("__CX16__", null);
    tc.addIncludePath(sdk_dep.path("mos-platform/cx16"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn c64HeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/c64/c64.h"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = false,
    });
    tc.defineCMacro("__C64__", null);
    tc.addIncludePath(sdk_dep.path("mos-platform/c64"));
    tc.addIncludePath(sdk_dep.path("mos-platform/commodore"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn lynxHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/lynx/lynx.h"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = false,
    });
    tc.defineCMacro("__LYNX__", null);
    tc.addIncludePath(sdk_dep.path("mos-platform/lynx"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn nesMapperHeaderMod(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    platform: []const u8,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path(b.fmt("mos-platform/{s}/mapper.h", .{platform})),
        .target = target,
        .optimize = .ReleaseFast,
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
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/atari8-common/_gtia.h"),
        .target = target,
        .optimize = .ReleaseFast,
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
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = sdk_dep.path("mos-platform/sim/sim-io.h"),
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = false,
    });
    tc.addIncludePath(sdk_dep.path("mos-platform/sim"));
    tc.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    return tc.createModule();
}

fn addApple2Exe(
    b: *std.Build,
    sdk_dep: *std.Build.Dependency,
    sdk_src: []const u8,
    apple2_sdk: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .freestanding });

    const lib_root = b.fmt("{s}/src/lib", .{apple2_sdk});

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/common/include\n" ++
            "sys_include_dir={s}/mos-platform/common/include\n" ++
            "crt_dir={s}/mos-platform/common\n" ++
            "msvc_lib_dir=\nkernel32_lib_dir=\ngcc_dir=\n",
        .{ sdk_src, sdk_src, sdk_src },
    ));

    const exe = b.addExecutable(.{
        .name = "apple2-hello",
        .root_module = b.createModule(.{
            .root_source_file = b.path("apple2/hello/hello.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.lto = .full;
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-iie-prodos", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-iie-prodos-cli", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-iie-prodos-hires", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-ii", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-iie", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-ii-bare", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-iie-bare", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-ii-autostart-rom", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-iie-autostart-rom", .{lib_root}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/apple-iie-prodos-stdlib", .{lib_root}) });
    exe.root_module.addCSourceFiles(.{
        .files = &.{
            b.fmt("{s}/apple-iie-prodos/prodos-syscall.c", .{lib_root}),
            b.fmt("{s}/apple-iie-prodos-stdlib/prodos-char-io.c", .{lib_root}),
            b.fmt("{s}/apple-iie-prodos-stdlib/prodos-exit.c", .{lib_root}),
        },
        .flags = &.{},
    });
    exe.root_module.addIncludePath(sdk_dep.path("mos-platform/common/include"));
    exe.root_module.linkSystemLibrary("c", .{ .use_pkg_config = .no });
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(.{ .cwd_relative = b.fmt("{s}/src/lib/apple-ii-bare/link.ld", .{apple2_sdk}) });

    return exe;
}
