const std = @import("std");

pub fn build(b: *std.Build) void {
    const sdk = b.option([]const u8, "sdk", "Path to llvm-mos-sdk") orelse
        std.fs.path.resolve(b.allocator, &.{
            b.build_root.path orelse ".",
            "../llvm-mos-sdk",
        }) catch @panic("cannot resolve sdk path");

    const mega65_libc = b.option([]const u8, "mega65-libc", "Path to mega65-libc checkout (required for mega65 examples)");
    const apple2_sdk = b.option([]const u8, "apple2-sdk", "Path to apple-ii-port-work checkout (required for apple2 examples)");

    // Translate neslib.h and nesdoug.h from the MOS SDK into Zig modules using
    // the built-in translate-c (avoids external dependency incompatibilities).
    const nes_target = b.resolveTargetQuery(.{ .cpu_arch = .mos, .os_tag = .nes });
    const neslib_mod = nesHeaderMod(b, sdk, nes_target, "neslib");
    const nesdoug_mod = nesHeaderMod(b, sdk, nes_target, "nesdoug");

    // Translate mega65.h into a Zig module (struct types + hardware constants).
    const mega65_target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos45gs02 },
    });
    const mega65_mod = mega65HeaderMod(b, sdk, mega65_target);

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
        const exe = addNesExe(b, sdk, "hello1", "nesdoug/hello1/hello1.zig", "nesdoug/hello1/Alpha.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello1.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "hello1");
    }

    // ---- NES hello2 ----
    {
        const step = b.step("nes-hello2", "Build NES hello2 example");
        const exe = addNesExe(b, sdk, "hello2", "nesdoug/hello2/hello2.zig", "nesdoug/hello2/Alpha.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello2.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "hello2");
    }

    // ---- NES hello3 ----
    {
        const step = b.step("nes-hello3", "Build NES hello3 example");
        const exe = addNesExe(b, sdk, "hello3", "nesdoug/hello3/hello3.zig", "nesdoug/hello3/Alpha.chr", true);
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
        const exe = addNesExe(b, sdk, "zig-logo", "nesdoug/zig-logo/zig-logo.zig", "nesdoug/zig-logo/zig-mark.chr", false);
        exe.root_module.addImport("neslib", neslib_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "zig-logo.nes" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
        addNesLabels(b, elf2mlb, gen_labels, exe, "zig-logo");
    }

    // ---- C64 hello ----
    {
        const step = b.step("c64-hello", "Build C64 hello example");
        const exe = addC64Exe(b, sdk, "c64-hello", "c64/hello/hello.zig", false);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "c64-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }

    // ---- C64 fibonacci ----
    {
        const step = b.step("c64-fibonacci", "Build C64 fibonacci example");
        const exe = addC64Exe(b, sdk, "fibonacci", "c64/fibonacci/fibonacci.zig", true);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "fibonacci.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }

    // ---- MEGA65 hello ----
    if (mega65_libc) |m65_libc| {
        const step = b.step("mega65-hello", "Build MEGA65 hello example");
        const exe = addMega65Exe(b, sdk, m65_libc, "mega65-hello", "mega65/hello/hello.zig");
        exe.root_module.addImport("mega65", mega65_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "mega65-hello.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    } else {
        const step = b.step("mega65-hello", "Build MEGA65 hello example (requires -Dmega65-libc=<path>)");
        _ = step;
        std.log.info("mega65-hello: skipping (pass -Dmega65-libc=<path> to enable)", .{});
    }

    // ---- MEGA65 plasma ----
    if (mega65_libc) |m65_libc| {
        const step = b.step("mega65-plasma", "Build MEGA65 plasma example");
        const exe = addMega65Exe(b, sdk, m65_libc, "plasma", "mega65/plasma/plasma.zig");
        exe.root_module.addImport("mega65", mega65_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "plasma.prg" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    } else {
        const step = b.step("mega65-plasma", "Build MEGA65 plasma example (requires -Dmega65-libc=<path>)");
        _ = step;
    }

    // ---- Neo6502 graphics ----
    {
        const neo6502_target = b.resolveTargetQuery(.{
            .cpu_arch = .mos,
            .os_tag = .freestanding,
            .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 },
        });
        const neo6502_mod = neo6502HeaderMod(b, sdk, neo6502_target);
        const step = b.step("neo6502-graphics", "Build Neo6502 graphics example");
        const exe = addNeo6502Exe(b, sdk);
        exe.root_module.addImport("neo6502", neo6502_mod);
        const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "graphics.neo" });
        step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }

    // ---- Apple2 hello ----
    if (apple2_sdk) |a2_sdk| {
        const step = b.step("apple2-hello", "Build Apple2 hello example");
        const exe = addApple2Exe(b, sdk, a2_sdk);
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
    sdk: []const u8,
    target: std.Build.ResolvedTarget,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = b.fmt("{s}/mos-platform/neo6502/include/neo/api.h", .{sdk}) },
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = false,
    });
    tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/neo6502/include", .{sdk}) });
    tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/neo6502/include/neo", .{sdk}) });
    tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/include", .{sdk}) });
    return tc.createModule();
}

fn mega65HeaderMod(
    b: *std.Build,
    sdk: []const u8,
    target: std.Build.ResolvedTarget,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = b.fmt("{s}/mos-platform/mega65/include/mega65.h", .{sdk}) },
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = false,
    });
    tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/mega65/include", .{sdk}) });
    tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/c64/include", .{sdk}) });
    tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/include", .{sdk}) });
    return tc.createModule();
}

fn nesHeaderMod(
    b: *std.Build,
    sdk: []const u8,
    target: std.Build.ResolvedTarget,
    header_name: []const u8,
) *std.Build.Module {
    const tc = b.addTranslateC(.{
        .root_source_file = .{ .cwd_relative = b.fmt("{s}/mos-platform/nes/include/{s}.h", .{ sdk, header_name }) },
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = false,
    });
    tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/nes/include", .{sdk}) });
    tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/include", .{sdk}) });
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
    sdk: []const u8,
    name: []const u8,
    root_src: []const u8,
    chr_src: []const u8,
    with_nesdoug: bool,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 },
    });

    const wf = b.addWriteFiles();
    const wrapper_ld = wf.add("nes-nrom-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/nes-nrom/lib");
        \\SEARCH_DIR("{s}/mos-platform/nes/lib");
        \\SEARCH_DIR("{s}/mos-platform/common/lib");
        \\INCLUDE "{s}/mos-platform/nes-nrom/lib/link.ld"
    , .{ sdk, sdk, sdk, sdk }));

    const chr_wf = b.addWriteFiles();
    const chr_asm = chr_wf.add("chr-rom-abs.s", b.fmt(
        \\.section .chr_rom,"a",@progbits
        \\.incbin "{s}/{s}"
    , .{ b.build_root.path orelse ".", chr_src }));

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
    exe.root_module.addObjectFile(.{ .cwd_relative = b.fmt("{s}/mos-platform/nes-nrom/lib/crt0.o", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/nes-nrom/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/nes/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/lib", .{sdk}) });
    exe.root_module.linkSystemLibrary("neslib", .{ .use_pkg_config = .no });
    if (with_nesdoug) exe.root_module.linkSystemLibrary("nesdoug", .{ .use_pkg_config = .no });
    exe.root_module.linkSystemLibrary("crt0", .{ .use_pkg_config = .no });
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addC64Exe(
    b: *std.Build,
    sdk: []const u8,
    name: []const u8,
    root_src: []const u8,
    with_printf_flt: bool,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
    });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt("include_dir={s}/mos-platform/c64/include\n" ++
        "sys_include_dir={s}/mos-platform/common/include\n" ++
        "crt_dir={s}/mos-platform/c64/lib\n" ++
        "msvc_lib_dir=\n" ++
        "kernel32_lib_dir=\n" ++
        "gcc_dir=\n", .{ sdk, sdk, sdk }));

    const wf2 = b.addWriteFiles();
    const wrapper_ld = wf2.add("c64-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/c64/lib");
        \\SEARCH_DIR("{s}/mos-platform/commodore/lib");
        \\SEARCH_DIR("{s}/mos-platform/common/lib");
        \\INCLUDE "{s}/mos-platform/c64/lib/link.ld"
    , .{ sdk, sdk, sdk, sdk }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/c64/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/commodore/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/lib", .{sdk}) });
    exe.root_module.linkSystemLibrary("crt0", .{ .use_pkg_config = .no });
    exe.root_module.linkSystemLibrary("c", .{ .use_pkg_config = .no });
    if (with_printf_flt) exe.root_module.linkSystemLibrary("printf_flt", .{ .use_pkg_config = .no });
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addMega65Exe(
    b: *std.Build,
    sdk: []const u8,
    mega65_libc: []const u8,
    name: []const u8,
    root_src: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos45gs02 },
    });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt("include_dir={s}/mos-platform/mega65/include\n" ++
        "sys_include_dir={s}/mos-platform/common/include\n" ++
        "crt_dir={s}/mos-platform/mega65/lib\n" ++
        "msvc_lib_dir=\n" ++
        "kernel32_lib_dir=\n" ++
        "gcc_dir=\n", .{ sdk, sdk, sdk }));

    const wf2 = b.addWriteFiles();
    const wrapper_ld = wf2.add("mega65-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/mega65/lib");
        \\SEARCH_DIR("{s}/mos-platform/c64/lib");
        \\SEARCH_DIR("{s}/mos-platform/commodore/lib");
        \\SEARCH_DIR("{s}/mos-platform/common/lib");
        \\INCLUDE "{s}/mos-platform/mega65/lib/link.ld"
    , .{ sdk, sdk, sdk, sdk, sdk }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_src),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.root_module.addAssemblyFile(.{ .cwd_relative = b.fmt("{s}/src/llvm/memory_asm.s", .{mega65_libc}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{mega65_libc}) });
    exe.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include/mega65", .{mega65_libc}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/mega65/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/c64/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/commodore/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/lib", .{sdk}) });
    exe.root_module.linkSystemLibrary("crt0", .{ .use_pkg_config = .no });
    exe.root_module.linkSystemLibrary("c", .{ .use_pkg_config = .no });
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addNeo6502Exe(
    b: *std.Build,
    sdk: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 },
    });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt("include_dir={s}/mos-platform/neo6502/include\n" ++
        "sys_include_dir={s}/mos-platform/common/include\n" ++
        "crt_dir={s}/mos-platform/neo6502/lib\n" ++
        "msvc_lib_dir=\n" ++
        "kernel32_lib_dir=\n" ++
        "gcc_dir=\n", .{ sdk, sdk, sdk }));

    const wf2 = b.addWriteFiles();
    const wrapper_ld = wf2.add("neo6502-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/neo6502/lib");
        \\SEARCH_DIR("{s}/mos-platform/common/lib");
        \\INCLUDE "{s}/mos-platform/neo6502/lib/link.ld"
    , .{ sdk, sdk, sdk }));

    const exe = b.addExecutable(.{
        .name = "graphics",
        .root_module = b.createModule(.{
            .root_source_file = b.path("neo6502/graphics.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/neo6502/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/lib", .{sdk}) });
    exe.root_module.linkSystemLibrary("crt0", .{ .use_pkg_config = .no });
    exe.root_module.linkSystemLibrary("c", .{ .use_pkg_config = .no });
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(wrapper_ld);

    return exe;
}

fn addApple2Exe(
    b: *std.Build,
    sdk: []const u8,
    apple2_sdk: []const u8,
) *std.Build.Step.Compile {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
    });

    const lib_root = b.fmt("{s}/src/lib", .{apple2_sdk});

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt("include_dir={s}/mos-platform/common/include\n" ++
        "sys_include_dir={s}/mos-platform/common/include\n" ++
        "crt_dir={s}/mos-platform/common/lib\n" ++
        "msvc_lib_dir=\n" ++
        "kernel32_lib_dir=\n" ++
        "gcc_dir=\n", .{ sdk, sdk, sdk }));

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
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/lib", .{sdk}) });
    exe.root_module.linkSystemLibrary("c", .{ .use_pkg_config = .no });
    exe.setLibCFile(libc_txt);
    exe.root_module.link_libc = true;
    exe.setLinkerScript(.{ .cwd_relative = b.fmt("{s}/src/lib/apple-ii-bare/link.ld", .{apple2_sdk}) });

    return exe;
}
