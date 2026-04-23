const std = @import("std");
const sdk_mod = @import("sdk/build.zig");

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

    var sdk_sim_libs:     sdk_mod.Libs = undefined;
    var sdk_mega65_libs:  sdk_mod.Libs = undefined;
    var sdk_c64_libs:     sdk_mod.Libs = undefined;
    var sdk_nes_libs:     sdk_mod.Libs = undefined;
    var sdk_neo6502_libs: sdk_mod.Libs = undefined;

    for ([_]sdk_mod.Platform{
        .{ .name = "sim",     .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 } } },
        .{ .name = "mega65",  .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos45gs02 } } },
        .{ .name = "c64",     .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 } } },
        .{ .name = "nes",     .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "neo6502", .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 } } },
    }) |pd| {
        const libs = sdk_mod.buildPlatform(b, sdk_src_raw, pd);
        const dest = b.fmt("mos-platform/{s}/lib", .{pd.name});
        for ([3]*std.Build.Step.Compile{ libs.crt, libs.crt0, libs.c }) |lib| {
            sdk_step.dependOn(&b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        }
        if (libs.neslib)  |l| sdk_step.dependOn(&b.addInstallArtifact(l, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        if (libs.nesdoug) |l| sdk_step.dependOn(&b.addInstallArtifact(l, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
        if (std.mem.eql(u8, pd.name, "sim"))     sdk_sim_libs     = libs;
        if (std.mem.eql(u8, pd.name, "mega65"))  sdk_mega65_libs  = libs;
        if (std.mem.eql(u8, pd.name, "c64"))     sdk_c64_libs     = libs;
        if (std.mem.eql(u8, pd.name, "nes"))     sdk_nes_libs     = libs;
        if (std.mem.eql(u8, pd.name, "neo6502")) sdk_neo6502_libs = libs;
    }

    // Translate neslib.h and nesdoug.h from the MOS SDK into Zig modules.
    const nes_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .nes });
    const neslib_mod  = nesHeaderMod(b, sdk_dep, nes_target, "neslib");
    const nesdoug_mod = nesHeaderMod(b, sdk_dep, nes_target, "nesdoug");

    // Translate mega65.h into a Zig module.
    const mega65_target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos45gs02 },
    });
    const mega65_mod = mega65HeaderMod(b, sdk_dep, mega65_target);

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

    const gen_labels = b.step("gen-labels", "Generate Mesen label files (.mlb) and install debug ELFs");

    // ---- NES hello1 ----
    {
        const step = b.step("nes-hello1", "Build NES hello1 example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_nes_libs, "hello1", "nesdoug/hello1/hello1.zig", "nesdoug/hello1/Alpha.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello1.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "hello1");
    }

    // ---- NES hello2 ----
    {
        const step = b.step("nes-hello2", "Build NES hello2 example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_nes_libs, "hello2", "nesdoug/hello2/hello2.zig", "nesdoug/hello2/Alpha.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello2.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "hello2");
    }

    // ---- NES hello3 ----
    {
        const step = b.step("nes-hello3", "Build NES hello3 example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_nes_libs, "hello3", "nesdoug/hello3/hello3.zig", "nesdoug/hello3/Alpha.chr", true);
        exe.root_module.addImport("neslib", neslib_mod);
        exe.root_module.addImport("nesdoug", nesdoug_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello3.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "hello3");
    }

    // ---- NES zig-logo ----
    {
        const step = b.step("nes-zig-logo", "Build NES Zig logo display example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_nes_libs, "zig-logo", "nesdoug/zig-logo/zig-logo.zig", "nesdoug/zig-logo/zig-mark.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "zig-logo.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "zig-logo");
    }

    // ---- NES fade ----
    {
        const step = b.step("nes-fade", "Build NES palette fade example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_nes_libs, "fade", "nesdoug/fade/fade.zig", "nesdoug/fade/Alpha.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fade.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "fade");
    }

    // ---- NES sprites ----
    {
        const step = b.step("nes-sprites", "Build NES sprites example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_nes_libs, "sprites", "nesdoug/sprites/sprites.zig", "nesdoug/sprites/Alpha.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "sprites.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "sprites");
    }

    // ---- NES pads ----
    {
        const step = b.step("nes-pads", "Build NES controller input example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_nes_libs, "pads", "nesdoug/pads/pads.zig", "nesdoug/pads/Alpha.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "pads.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "pads");
    }

    // ---- NES color-cycle ----
    {
        const step = b.step("nes-color-cycle", "Build NES palette colour-cycle example");
        const exe = addNesExe(b, sdk_dep, sdk_src, sdk_nes_libs, "color-cycle", "nesdoug/color-cycle/color-cycle.zig", "nesdoug/color-cycle/Alpha.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "color-cycle.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "color-cycle");
    }

    // ---- C64 hello ----
    {
        const step = b.step("c64-hello", "Build C64 hello example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_c64_libs, "c64-hello", "c64/hello/hello.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }

    // ---- C64 fibonacci ----
    {
        const step = b.step("c64-fibonacci", "Build C64 fibonacci example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_c64_libs, "fibonacci", "c64/fibonacci/fibonacci.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fibonacci.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }

    // ---- C64 plasma ----
    {
        const step = b.step("c64-plasma", "Build C64 plasma effect example");
        const exe = addC64Exe(b, sdk_dep, sdk_src, sdk_c64_libs, "plasma", "c64/plasma/plasma.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "plasma.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }

    // ---- MEGA65 (mega65-libc fetched automatically via build.zig.zon) ----
    if (b.lazyDependency("mega65-libc", .{})) |m65_dep| {
        {
            const step = b.step("mega65-hello", "Build MEGA65 hello example");
            const exe = addMega65Exe(b, sdk_dep, sdk_src, sdk_mega65_libs, m65_dep, "mega65-hello", "mega65/hello/hello.zig");
            exe.root_module.addImport("mega65", mega65_mod);
            const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mega65-hello.prg" });
            step.dependOn(&install.step);
            b.getInstallStep().dependOn(&install.step);
        }
        {
            const step = b.step("mega65-plasma", "Build MEGA65 plasma example");
            const exe = addMega65Exe(b, sdk_dep, sdk_src, sdk_mega65_libs, m65_dep, "plasma", "mega65/plasma/plasma.zig");
            exe.root_module.addImport("mega65", mega65_mod);
            const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "plasma.prg" });
            step.dependOn(&install.step);
            b.getInstallStep().dependOn(&install.step);
        }
    } else {
        inline for (.{ "mega65-hello", "mega65-plasma" }) |name| {
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
        const exe = addNeo6502Exe(b, sdk_dep, sdk_src, sdk_neo6502_libs);
        exe.root_module.addImport("neo6502", neo6502_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "graphics.neo" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }

    // ---- sim hello ----
    {
        const step = b.step("sim-hello", "Build mos-sim hello example (run with mos-sim zig-out/bin/sim-hello)");
        const exe = addSimExe(b, sdk_dep, sdk_src, sdk_sim_libs, "sim-hello", "sim/hello/hello.zig");
        const install = b.addInstallArtifact(exe, .{});
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
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
    const target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .nes });

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
    if (libs.neslib)  |neslib|  exe.root_module.linkLibrary(neslib);
    if (with_nesdoug) if (libs.nesdoug) |nesdoug| exe.root_module.linkLibrary(nesdoug);
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
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos45gs02 },
    });

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
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 },
    });

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
    exe.root_module.addAssemblyFile(b.path("sim/call_main.s"));
    exe.root_module.linkLibrary(libs.crt);
    exe.root_module.linkLibrary(libs.crt0);
    exe.root_module.linkLibrary(libs.c);
    exe.setLinkerScript(wrapper_ld);
    _ = sdk_dep;

    return exe;
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
