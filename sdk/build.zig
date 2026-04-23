//! llvm-mos-sdk platform library builder.
//!
//! Standalone:  zig build [-Dplatform=sim|mega65|c64|nes|neo6502]
//! As import:   const sdk = @import("sdk/build.zig");
//!              const libs = sdk.buildPlatform(b, sdk_src, platform);
//!              exe.step.dependOn(&libs.crt.step);

const std = @import("std");

pub const Platform = struct {
    name: []const u8,
    query: std.Target.Query,
};

pub const Libs = struct {
    crt:     *std.Build.Step.Compile,
    crt0:    *std.Build.Step.Compile,
    c:       *std.Build.Step.Compile,
    neslib:  ?*std.Build.Step.Compile = null,
    nesdoug: ?*std.Build.Step.Compile = null,
};

/// Build platform libraries for `pd` from the SDK source tree at `sdk_root`.
/// Returns the compile artifacts; the caller decides how to install/link them.
pub fn buildPlatform(b: *std.Build, sdk_root: []const u8, pd: Platform) Libs {
    const target = b.resolveTargetQuery(pd.query);
    const opt: std.builtin.OptimizeMode = .ReleaseFast;

    const common   = b.fmt("{s}/mos-platform/common", .{sdk_root});
    const com_inc  = b.fmt("{s}/include", .{common});
    const com_asm  = b.fmt("{s}/asminc", .{common});
    const crt_dir  = b.fmt("{s}/crt",    .{common});
    const crt0_dir = b.fmt("{s}/crt0",   .{common});
    const plat_dir = b.fmt("{s}/mos-platform/{s}", .{ sdk_root, pd.name });
    const comm_dir = b.fmt("{s}/mos-platform/commodore", .{sdk_root});

    // libcrt — compiler runtime builtins (all platforms share this).
    const libcrt = addLib(b, "crt", target, opt);
    libcrt.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt_dir },
        .files = &.{ "const.S", "call-indir.S", "divmod.cc", "divmod-large.cc", "mul.cc", "shift.cc", "rotate.cc" },
        .flags = &.{ b.fmt("-I{s}", .{crt_dir}), b.fmt("-I{s}", .{com_inc}), b.fmt("-I{s}", .{com_asm}) },
    });

    if (std.mem.eql(u8, pd.name, "nes"))
        return buildNes(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "neo6502"))
        return buildNeo6502(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);

    // libcrt0 — startup: stack init + data copy + exit handler.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
        .flags = &.{b.fmt("-I{s}", .{com_asm})},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{"copy-zp-data.c"},
        .flags = &.{ "-fno-lto", b.fmt("-I{s}", .{com_inc}) },
    });
    const exit_file: []const u8 = if (std.mem.eql(u8, pd.name, "sim")) "exit-custom.S" else "exit-loop.c";
    const exit_flags: []const []const u8 = if (std.mem.eql(u8, pd.name, "sim"))
        &.{b.fmt("-I{s}", .{com_asm})}
    else
        &.{ "-fno-lto", b.fmt("-I{s}", .{com_inc}) };
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{exit_file},
        .flags = exit_flags,
    });

    // libc — platform I/O and kernal wrappers.
    const libc = addLib(b, "c", target, opt);
    if (std.mem.eql(u8, pd.name, "sim")) {
        libc.root_module.addCSourceFiles(.{
            .root  = .{ .cwd_relative = plat_dir },
            .files = &.{ "putchar.c", "stdlib.c", "sim-io.c" },
            .flags = &.{ b.fmt("-I{s}", .{plat_dir}), b.fmt("-I{s}", .{com_inc}) },
        });
    } else {
        const asm_files: []const []const u8 = if (std.mem.eql(u8, pd.name, "mega65"))
            &.{ "filevars.s", "kernal.S" }
        else
            &.{ "basic-header.S", "kernal.S", "unmap-basic.S", "devnum.s" };
        libc.root_module.addCSourceFiles(.{
            .root  = .{ .cwd_relative = plat_dir },
            .files = asm_files,
            .flags = &.{ b.fmt("-I{s}", .{plat_dir}), b.fmt("-I{s}", .{comm_dir}), b.fmt("-I{s}", .{com_asm}) },
        });
        libc.root_module.addCSourceFiles(.{
            .root  = .{ .cwd_relative = comm_dir },
            .files = &.{ "abort.c", "cbm_k_bsout.c", "cbm_k_chrout.c", "chrout.c", "char-conv.c" },
            .flags = &.{ b.fmt("-I{s}", .{comm_dir}), b.fmt("-I{s}", .{com_inc}) },
        });
    }

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildNes(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    nes_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const neslib_dir  = b.fmt("{s}/neslib",  .{nes_dir});
    const nesdoug_dir = b.fmt("{s}/nesdoug", .{nes_dir});

    // libcrt0 — NES startup: copy-data + zero-bss + exit-loop + NES crt0.c.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
        .flags = &.{b.fmt("-I{s}", .{com_asm})},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-data.c", "copy-zp-data.c", "zero-bss.c", "zero-zp-bss.c" },
        .flags = &.{ "-fno-lto", b.fmt("-I{s}", .{com_inc}) },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = &.{ "-fno-lto", b.fmt("-I{s}", .{com_inc}) },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = nes_dir },
        .files = &.{"crt0.c"},
        .flags = &.{ b.fmt("-I{s}", .{nes_dir}), b.fmt("-I{s}", .{com_inc}) },
    });

    // libc (nes-c) — putchar + rompoke.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = nes_dir },
        .files = &.{"putchar.c"},
        .flags = &.{ b.fmt("-I{s}", .{nes_dir}), b.fmt("-I{s}", .{com_inc}), b.fmt("-I{s}", .{com_asm}) },
    });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/rompoke", .{nes_dir}) },
        .files = &.{"rompoke.c"},
        .flags = &.{ b.fmt("-I{s}", .{nes_dir}), b.fmt("-I{s}", .{com_inc}) },
    });

    // libneslib.
    const libneslib = addLib(b, "neslib", target, opt);
    libneslib.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = neslib_dir },
        .files = &.{
            "neslib.c",    "neslib.s",
            "ntsc.c",      "ntsc.s",
            "oam_update.c","oam_update.s",
            "pal_bright.c","pal_bright.s",
            "pal_update.c","pal_update.s",
            "rand.c",      "rand.s",
            "vram_update.c","vram_update.s",
        },
        .flags = &.{
            b.fmt("-I{s}", .{neslib_dir}),
            b.fmt("-I{s}", .{nes_dir}),
            b.fmt("-I{s}", .{com_asm}),
            b.fmt("-I{s}", .{com_inc}),
        },
    });

    // libnesdoug.
    const libnesdoug = addLib(b, "nesdoug", target, opt);
    libnesdoug.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = nesdoug_dir },
        .files = &.{
            "metatile.c",       "metatile.s",
            "nesdoug.c",        "nesdoug.s",
            "padlib.s",
            "vram_buffer.c",    "vram_buffer.s",
            "vram_buffer_ops.s","zaplib.s",
        },
        .flags = &.{
            b.fmt("-I{s}", .{nesdoug_dir}),
            b.fmt("-I{s}", .{neslib_dir}),
            b.fmt("-I{s}", .{nes_dir}),
            b.fmt("-I{s}", .{com_asm}),
            b.fmt("-I{s}", .{com_inc}),
        },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc, .neslib = libneslib, .nesdoug = libnesdoug };
}

fn buildNeo6502(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    neo_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    // libcrt0 — common startup + copy-zp-data + exit-loop.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
        .flags = &.{b.fmt("-I{s}", .{com_asm})},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{"copy-zp-data.c"},
        .flags = &.{ "-fno-lto", b.fmt("-I{s}", .{com_inc}) },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = &.{ "-fno-lto", b.fmt("-I{s}", .{com_inc}) },
    });

    // libc (neo6502-c) — API + platform I/O.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/api", .{neo_dir}) },
        .files = &.{
            "api-internal.c", "console.c",    "controller.c", "file.c",
            "graphics.c",     "sound.c",      "sprites.c",    "system.c",
            "turtle.c",       "uext.c",       "mouse.c",
        },
        .flags = &.{ b.fmt("-I{s}", .{neo_dir}), b.fmt("-I{s}", .{com_inc}) },
    });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = neo_dir },
        .files = &.{ "char-conv.c", "clock.c", "getchar.c", "putchar.c" },
        .flags = &.{ b.fmt("-I{s}", .{neo_dir}), b.fmt("-I{s}", .{com_inc}) },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

// ── Standalone entry point ────────────────────────────────────────────────────

pub fn build(b: *std.Build) void {
    const sdk_root = b.build_root.path orelse ".";
    const filter   = b.option([]const u8, "platform", "Build only this platform (sim, mega65, c64, nes, neo6502)");

    for ([_]Platform{
        .{ .name = "sim",     .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 } } },
        .{ .name = "mega65",  .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos45gs02 } } },
        .{ .name = "c64",     .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 } } },
        .{ .name = "nes",     .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "neo6502", .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 } } },
    }) |pd| {
        if (filter) |f| if (!std.mem.eql(u8, f, pd.name)) continue;
        const libs = buildPlatform(b, sdk_root, pd);
        installLib(b, libs.crt,  pd.name);
        installLib(b, libs.crt0, pd.name);
        installLib(b, libs.c,    pd.name);
        if (libs.neslib)  |l| installLib(b, l, pd.name);
        if (libs.nesdoug) |l| installLib(b, l, pd.name);
    }
}

fn addLib(b: *std.Build, name: []const u8, target: std.Build.ResolvedTarget, opt: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    return b.addLibrary(.{ .name = name, .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = opt }) });
}

fn installLib(b: *std.Build, lib: *std.Build.Step.Compile, platform: []const u8) void {
    const dest = b.fmt("mos-platform/{s}/lib", .{platform});
    b.getInstallStep().dependOn(&b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
}
