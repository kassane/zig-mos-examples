// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
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
    crt: *std.Build.Step.Compile,
    crt0: *std.Build.Step.Compile,
    c: *std.Build.Step.Compile,
    neslib: ?*std.Build.Step.Compile = null,
    nesdoug: ?*std.Build.Step.Compile = null,
    nes_c: ?*std.Build.Step.Compile = null,
    // NES only: startup C files (copy-data, zero-bss, exit-loop) with lto = .none.
    nes_c_startup: ?*std.Build.Step.Compile = null,
    // Platforms that need a strong __memset (overrides the weak recursive stub):
    // built as a TRUE object so ld.lld sees the strong definition before the archive.
    mem: ?*std.Build.Step.Compile = null,
};

/// Build platform libraries for `pd` from the SDK source tree at `sdk_root`.
/// Returns the compile artifacts; the caller decides how to install/link them.
pub fn buildPlatform(b: *std.Build, sdk_root: []const u8, pd: Platform, opt: std.builtin.OptimizeMode) Libs {
    const target = b.resolveTargetQuery(pd.query);

    const common = b.fmt("{s}/mos-platform/common", .{sdk_root});
    const com_inc = b.fmt("{s}/include", .{common});
    const com_asm = b.fmt("{s}/asminc", .{common});
    const crt_dir = b.fmt("{s}/crt", .{common});
    const crt0_dir = b.fmt("{s}/crt0", .{common});
    const plat_dir = b.fmt("{s}/mos-platform/{s}", .{ sdk_root, pd.name });
    const comm_dir = b.fmt("{s}/mos-platform/commodore", .{sdk_root});

    // libcrt — compiler runtime builtins (all platforms share this).
    const libcrt = addLib(b, "crt", target, .ReleaseFast);
    libcrt.root_module.addIncludePath(.{ .cwd_relative = crt_dir });
    libcrt.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    // sim: Zig's ZCU emits its own math builtins (__udivhi3, __mulhi3, etc.)
    // so omit the .cc files to avoid duplicate symbol errors at link time.
    const crt_files: []const []const u8 = if (std.mem.eql(u8, pd.name, "sim"))
        &.{ "const.S", "call-indir.S" }
    else
        &.{ "const.S", "call-indir.S", "divmod.cc", "divmod-large.cc", "mul.cc", "shift.cc", "rotate.cc" };
    libcrt.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt_dir },
        .files = crt_files,
    });

    if (std.mem.eql(u8, pd.name, "nes"))
        return buildNes(b, target, opt, libcrt, plat_dir, null, null, false, false, crt0_dir, com_inc, com_asm);
    if (std.mem.startsWith(u8, pd.name, "nes-")) {
        const has_mapper_s = std.mem.eql(u8, pd.name, "nes-unrom") or std.mem.eql(u8, pd.name, "nes-unrom-512") or std.mem.eql(u8, pd.name, "nes-mmc1") or std.mem.eql(u8, pd.name, "nes-mmc3") or std.mem.eql(u8, pd.name, "nes-gtrom");
        const has_irq = std.mem.eql(u8, pd.name, "nes-mmc3");
        const variant_define: ?[]const u8 = if (std.mem.eql(u8, pd.name, "nes-cnrom")) "__NES_CNROM__" else if (std.mem.eql(u8, pd.name, "nes-unrom")) "__NES_UNROM__" else if (std.mem.eql(u8, pd.name, "nes-unrom-512")) "__NES_UNROM_512__" else if (std.mem.eql(u8, pd.name, "nes-mmc1")) "__NES_MMC1__" else if (std.mem.eql(u8, pd.name, "nes-mmc3")) "__NES_MMC3__" else if (std.mem.eql(u8, pd.name, "nes-gtrom")) "__NES_GTROM__" else null;
        return buildNes(b, target, opt, libcrt, b.fmt("{s}/mos-platform/nes", .{sdk_root}), b.fmt("{s}/mos-platform/{s}", .{ sdk_root, pd.name }), variant_define, has_mapper_s, has_irq, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "neo6502"))
        return buildNeo6502(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "atari2600-4k")) {
        const a26_dir = b.fmt("{s}/mos-platform/atari2600-common", .{sdk_root});
        return buildAtari2600_4k(b, target, opt, libcrt, a26_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "atari2600-3e")) {
        const a26_dir = b.fmt("{s}/mos-platform/atari2600-common", .{sdk_root});
        return buildAtari2600_4k(b, target, opt, libcrt, a26_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "atari5200-supercart")) {
        const a8_common_dir = b.fmt("{s}/mos-platform/atari8-common", .{sdk_root});
        return buildAtari5200Supercart(b, target, opt, libcrt, a8_common_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "atari8-dos")) {
        const a8_common_dir = b.fmt("{s}/mos-platform/atari8-common", .{sdk_root});
        const a8_dos_dir = b.fmt("{s}/mos-platform/atari8-dos", .{sdk_root});
        return buildAtari8Dos(b, target, opt, libcrt, a8_common_dir, a8_dos_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "snes"))
        return buildSnes(b, target, opt, libcrt, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "atari8-cart-std")) {
        const a8_common_dir = b.fmt("{s}/mos-platform/atari8-common", .{sdk_root});
        return buildAtari8CartStd(b, target, opt, libcrt, a8_common_dir, plat_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "cx16"))
        return buildCx16(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm, comm_dir);
    if (std.mem.eql(u8, pd.name, "lynx-bll")) {
        const lynx_dir = b.fmt("{s}/mos-platform/lynx", .{sdk_root});
        return buildLynxBll(b, target, opt, libcrt, lynx_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "pce")) {
        const pce_common_dir = b.fmt("{s}/mos-platform/pce-common", .{sdk_root});
        return buildPce(b, target, opt, libcrt, plat_dir, pce_common_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "pce-cd")) {
        const pce_common_dir = b.fmt("{s}/mos-platform/pce-common", .{sdk_root});
        return buildPceCd(b, target, opt, libcrt, plat_dir, pce_common_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "fds")) {
        const nes_dir = b.fmt("{s}/mos-platform/nes", .{sdk_root});
        return buildFds(b, target, opt, libcrt, plat_dir, nes_dir, crt0_dir, com_inc, com_asm);
    }
    if (std.mem.eql(u8, pd.name, "eater"))
        return buildEater(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "geos-cbm"))
        return buildGeosCbm(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "c128"))
        return buildC128(b, target, opt, libcrt, plat_dir, comm_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "pet"))
        return buildPet(b, target, opt, libcrt, plat_dir, comm_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "vic20"))
        return buildVic20(b, target, opt, libcrt, plat_dir, comm_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "rp6502"))
        return buildRp6502(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "rpc8e"))
        return buildRpc8e(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "supervision"))
        return buildSupervision(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "dodo"))
        return buildDodo(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "osi-c1p"))
        return buildOsiC1p(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.eql(u8, pd.name, "cpm65"))
        return buildCpm65(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);

    // libcrt0 — startup: stack init + data copy + exit handler.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"copy-zp-data.c"},
    });
    const exit_file: []const u8 = if (std.mem.eql(u8, pd.name, "sim")) "exit-custom.S" else "exit-loop.c";
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{exit_file},
    });

    // libc — platform I/O and kernal wrappers.
    const libc = addLib(b, "c", target, opt);
    if (std.mem.eql(u8, pd.name, "sim")) {
        libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
        libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
        libc.root_module.addCSourceFiles(.{
            .root = .{ .cwd_relative = plat_dir },
            .files = &.{ "putchar.c", "stdlib.c", "sim-io.c" },
        });
    } else {
        const asm_files: []const []const u8 = if (std.mem.eql(u8, pd.name, "mega65"))
            &.{ "filevars.s", "kernal.S" }
        else
            &.{ "basic-header.S", "kernal.S", "unmap-basic.S", "devnum.s" };
        libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
        libc.root_module.addIncludePath(.{ .cwd_relative = comm_dir });
        libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
        libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
        libc.root_module.addCSourceFiles(.{
            .root = .{ .cwd_relative = plat_dir },
            .files = asm_files,
        });
        libc.root_module.addCSourceFiles(.{
            .root = .{ .cwd_relative = comm_dir },
            .files = &.{ "abort.c", "cbm_k_bsout.c", "cbm_k_chrout.c", "chrout.c", "char-conv.c" },
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
    variant_dir: ?[]const u8,
    variant_define: ?[]const u8,
    has_mapper_s: bool,
    has_irq: bool,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const nes_cflags: []const []const u8 = &.{"-mlto-zp=224"};
    const neslib_dir = b.fmt("{s}/neslib", .{nes_dir});
    const nesdoug_dir = b.fmt("{s}/nesdoug", .{nes_dir});

    // libcrt0 — .S startup files only (NES target).
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
    });

    // libc (nes-c) — putchar + rompoke.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCMacro("__NES__", "1");
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = nes_dir },
        .files = &.{"putchar.c"},
        .flags = nes_cflags,
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/rompoke", .{nes_dir}) },
        .files = &.{"rompoke.c"},
        .flags = nes_cflags,
    });

    // libneslib — .s files only (NES target).
    const libneslib = addLib(b, "neslib", target, opt);
    libneslib.root_module.addIncludePath(.{ .cwd_relative = neslib_dir });
    libneslib.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libneslib.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libneslib.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libneslib.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = neslib_dir },
        .files = &.{ "neslib.s", "ntsc.s", "oam_update.s", "pal_bright.s", "pal_update.s", "rand.s", "vram_update.s" },
    });

    // libnesdoug — .s files only (NES target).
    const libnesdoug = addLib(b, "nesdoug", target, opt);
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = nesdoug_dir });
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = neslib_dir });
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libnesdoug.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = nesdoug_dir },
        .files = &.{ "metatile.s", "nesdoug.s", "padlib.s", "vram_buffer.s", "vram_buffer_ops.s", "zaplib.s" },
    });

    // libnes_c_startup — startup C files with lto = .none (must remain plain machine code).
    const libnes_c_startup = addLib(b, "nes-c-startup", target, opt);
    libnes_c_startup.lto = .none;
    libnes_c_startup.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libnes_c_startup.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libnes_c_startup.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    // mem.c — provides memcpy/memmove/memcmp/memchr.
    // sdk/mem.s overrides __memset, but must be a TRUE object linked directly
    // into each exe (not an archive member) — see build.zig addNes*Exe builders.
    // If placed in this archive, the linker satisfies __memset with the weak
    // definition from mem.c before scanning mem.s, so mem.s is never extracted.
    libnes_c_startup.root_module.addCMacro("__NES__", "1");
    libnes_c_startup.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/../c", .{crt0_dir}) },
        .files = &.{"mem.c"},
        .flags = nes_cflags,
    });
    libnes_c_startup.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-data.c", "copy-zp-data.c", "zero-bss.c", "zero-zp-bss.c" },
        .flags = nes_cflags,
    });
    libnes_c_startup.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = nes_cflags,
    });

    // libnes_c — NES C files that require LTO (ZP reservation via named sections).
    const libnes_c = addLib(b, "nes-c", target, opt);
    libnes_c.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libnes_c.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libnes_c.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libnes_c.root_module.addIncludePath(.{ .cwd_relative = neslib_dir });
    libnes_c.root_module.addIncludePath(.{ .cwd_relative = nesdoug_dir });
    libnes_c.root_module.addCMacro("__NES__", "1");
    libnes_c.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = nes_dir },
        .files = &.{"crt0.c"},
        .flags = nes_cflags,
    });
    // neslib C files — LTO required (via lib.lto = .full in addLib): neslib.c reserves
    // ZP variables via named sections; without LTO the compiler may reuse those ZP
    // addresses for other locals, corrupting neslib's NMI-driven state machine.
    libnes_c.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = neslib_dir },
        .files = &.{ "neslib.c", "ntsc.c", "oam_update.c", "pal_bright.c", "pal_update.c", "rand.c", "vram_update.c" },
        .flags = nes_cflags,
    });
    // nesdoug C files
    libnes_c.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = nesdoug_dir },
        .files = &.{ "metatile.c", "nesdoug.c", "vram_buffer.c" },
        .flags = nes_cflags,
    });

    // Banked-mapper platforms (nes-cnrom, nes-unrom, nes-mmc1) have a mapper.c and
    // optionally a mapper.s in their platform directory providing bank-switch functions.
    if (variant_dir) |vd| {
        libnes_c.root_module.addIncludePath(.{ .cwd_relative = vd });
        libnes_c.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/rompoke", .{nes_dir}) });
        if (variant_define) |vdef| libnes_c.root_module.addCMacro(vdef, "1");
        libnes_c.root_module.addCSourceFiles(.{
            .root = .{ .cwd_relative = vd },
            .files = &.{"mapper.c"},
            .flags = nes_cflags,
        });
        if (has_mapper_s) {
            libneslib.root_module.addCSourceFiles(.{
                .root = .{ .cwd_relative = vd },
                .files = &.{"mapper.s"},
            });
        }
        if (has_irq) {
            libnes_c.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
            libnes_c.root_module.addCSourceFiles(.{
                .root = .{ .cwd_relative = vd },
                .files = &.{"irq.c"},
                .flags = nes_cflags,
            });
            libnes_c.root_module.addCSourceFiles(.{
                .root = .{ .cwd_relative = vd },
                .files = &.{"irq.s"},
            });
        }
    }

    // sdk/mem.s — strong __memset + abort (TRUE object, lto = .none).
    // Must be linked directly into each exe, not placed in an archive.
    // mem.c's __memset is __attribute__((weak)); zig cc (clang 21) compiles it to a
    // broken recursive stub. sdk/mem.s provides the correct byte-store loop.
    const mem_obj = b.addObject(.{
        .name = "mem",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = opt,
        }),
    });
    mem_obj.root_module.addCSourceFiles(.{ .root = b.path("sdk"), .files = &.{"mem.s"} });
    mem_obj.lto = .none;

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc, .neslib = libneslib, .nesdoug = libnesdoug, .nes_c = libnes_c, .nes_c_startup = libnes_c_startup, .mem = mem_obj };
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
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"copy-zp-data.c"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    // libc (neo6502-c) — API + platform I/O.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/api", .{neo_dir}) });
    libc.root_module.addIncludePath(.{ .cwd_relative = neo_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/api", .{neo_dir}) },
        .files = &.{
            "api-internal.c", "console.c", "controller.c", "file.c",
            "graphics.c",     "sound.c",   "sprites.c",    "system.c",
            "turtle.c",       "uext.c",    "mouse.c",
        },
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = neo_dir },
        .files = &.{ "char-conv.c", "clock.c", "getchar.c", "putchar.c" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildSnes(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    // libcrt0: soft-stack init + data/BSS copy + exit.
    // The mode-switch crt0.S (snes/crt0.S) is added directly to each exe.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "init-stack.S", "copy-zp-data.c", "copy-data.c", "zero-bss.c", "zero-zp-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    // libc: mem.c provides memcpy/memmove/memcmp/memchr (but NOT __memset — see below).
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/../c", .{crt0_dir}) },
        .files = &.{"mem.c"},
    });

    // sdk/mem.s — strong __memset + abort (TRUE object, lto = .none).
    // mem.c's __memset is __attribute__((weak)); zig cc (clang 21) compiles it to a
    // broken recursive stub. sdk/mem.s provides the correct byte-store loop and
    // must land on the link line as a plain object, NOT inside an archive.
    const mem_obj = b.addObject(.{
        .name = "mem",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = opt,
        }),
    });
    mem_obj.root_module.addCSourceFiles(.{ .root = b.path("sdk"), .files = &.{"mem.s"} });
    mem_obj.lto = .none;

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc, .mem = mem_obj };
}

fn buildAtari2600_4k(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    a26_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    // libcrt0: copy-zp-data + copy-data + exit-loop (crt0.S is a standalone object added by the exe).
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-zp-data.c", "copy-data.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    // libc: frameloop + vcslib.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = a26_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a26_dir },
        .files = &.{ "frameloop.c", "vcslib.S" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildAtari5200Supercart(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    a8_common_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    // libcrt0: atari8-common stack init + common data/BSS copy + exit-loop (no OS).
    // Mirrors CMakeLists: merge common-init-stack + common-copy-data + common-zero-bss + common-exit-loop.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_common_dir },
        .files = &.{"init-stack.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-data.c", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    // libc: mem.c supplies memcpy/__memset used by copy-data.c / zero-bss.c.
    // Parent platform is 'common' (not atari8-common), so no IOCB I/O here.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/../c", .{crt0_dir}) },
        .files = &.{"mem.c"},
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildAtari8Dos(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    a8_common_dir: []const u8,
    a8_dos_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    // libcrt0: atari8-common init-stack + atari8-dos _Exit + common startup files.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_common_dir },
        .files = &.{"init-stack.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_dos_dir },
        .files = &.{"_Exit.c"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-zp-data.c", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-custom.S"},
    });

    // libc: atari8 I/O.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = a8_common_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_common_dir },
        .files = &.{ "putchar.c", "getchar.c" },
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_common_dir },
        .files = &.{
            "close.s",        "fdtab.s",     "fdtable.s", "fdtoiocb.s",
            "findfreeiocb.s", "getfd.s",     "open.s",    "oserror.s",
            "rwcommon.s",     "sysremove.s", "write.s",
        },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildCx16(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    cx16_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
    comm_dir: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "init-stack.S", "copy-zp-data.c", "zero-bss.c" },
        .flags = &.{"-D__CX16__"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-return.c"},
        .flags = &.{"-D__CX16__"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = cx16_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = comm_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = cx16_dir },
        .files = &.{
            "kernal.S",
            "cx16_k_bsave.s",
            "cx16_k_clock_get_date_time.s",
            "cx16_k_clock_set_date_time.s",
            "cx16_k_console_get_char.s",
            "cx16_k_console_init.s",
            "cx16_k_console_put_char.s",
            "cx16_k_console_put_image.s",
            "cx16_k_console_set_paging_message.s",
            "cx16_k_enter_basic.s",
            "cx16_k_entropy_get.s",
            "cx16_k_fb_cursor_next_line.s",
            "cx16_k_fb_cursor_position.s",
            "cx16_k_fb_fill_pixels.s",
            "cx16_k_fb_filter_pixels.s",
            "cx16_k_fb_get_info.s",
            "cx16_k_fb_get_pixel.s",
            "cx16_k_fb_get_pixels.s",
            "cx16_k_fb_init.s",
            "cx16_k_fb_move_pixels.s",
            "cx16_k_fb_set_8_pixels.s",
            "cx16_k_fb_set_8_pixels_opaque.s",
            "cx16_k_fb_set_palette.s",
            "cx16_k_graph_clear.s",
            "cx16_k_graph_draw_image.s",
            "cx16_k_graph_draw_line.s",
            "cx16_k_graph_draw_oval.s",
            "cx16_k_graph_draw_rect.s",
            "cx16_k_graph_get_char_size.s",
            "cx16_k_graph_init.s",
            "cx16_k_graph_move_rect.s",
            "cx16_k_graph_put_char.s",
            "cx16_k_graph_set_colors.s",
            "cx16_k_graph_set_font.s",
            "cx16_k_graph_set_window.s",
            "cx16_k_i2c_read_byte.s",
            "cx16_k_i2c_write_byte.s",
            "cx16_k_joystick_get.c",
            "cx16_k_joystick_scan.s",
            "cx16_k_kbdbuf_get_modifiers.s",
            "cx16_k_kbdbuf_peek.s",
            "cx16_k_kbdbuf_put.s",
            "cx16_k_keymap_get_id.s",
            "cx16_k_keymap_set.s",
            "cx16_k_macptr.s",
            "cx16_k_memory_copy.s",
            "cx16_k_memory_crc.s",
            "cx16_k_memory_decompress.s",
            "cx16_k_memory_fill.s",
            "cx16_k_monitor.s",
            "cx16_k_mouse_config.s",
            "cx16_k_mouse_get.s",
            "cx16_k_mouse_scan.s",
            "cx16_k_rdtim.s",
            "cx16_k_screen_mode_get.s",
            "cx16_k_screen_mode_set.s",
            "cx16_k_screen_set_charset.s",
            "cx16_k_sprite_set_image.s",
            "cx16_k_sprite_set_position.s",
            "filevars.s",
            "get_numbanks.s",
            "get_ostype.s",
            "get_tv.s",
            "set_tv.s",
            "vera_layer_enable.s",
            "vera_sprites_enable.s",
            "videomode.s",
            "vpeek.s",
            "vpoke.s",
            "waitvsync.s",
            "char-conv.c",
        },
        .flags = &.{"-D__CX16__"},
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = comm_dir },
        .files = &.{
            "abort.c",       "putchar.c",      "getchar.c",
            "cbm_k_bsout.c", "cbm_k_chrout.c", "chrout.c",
            "cbm_k_getin.c",
        },
        .flags = &.{"-D__CX16__"},
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildLynxBll(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    lynx_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "init-stack.S", "copy-zp-data.c", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    // lynx-c has no source files — emit a tiny stub so the static archive isn't empty.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = lynx_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    const stub_wf = b.addWriteFiles();
    const stub_c = stub_wf.add("lynx_stub.c", "// lynx-c stub — no platform sources required.\nstatic int lynx_stub_marker;\n");
    libc.root_module.addCSourceFile(.{ .file = stub_c, .flags = &.{} });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildPce(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    pce_dir: []const u8,
    pce_common_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libpce_src = b.fmt("{s}/libpce/src", .{pce_common_dir});
    const libpce_inc = b.fmt("{s}/libpce/include", .{pce_common_dir});
    // libcrt0: pce-specific crt0 files + common init-stack + exit-loop.
    // Note: crt0/crt0.S is a standalone object added per-exe (not in this lib).
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = pce_common_dir });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"init-stack.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/crt0", .{pce_dir}) },
        .files = &.{
            "copy-data.S",   "copy-zp-data.S",
            "irq.S",         "zero-bss.S",
            "zero-zp-bss.S",
        },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    // libc: pce-common libpce hardware library.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = libpce_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = pce_common_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = libpce_src },
        .files = &.{
            "bank.S",   "bank-c.c",
            "joypad.c", "memory.S",
            "psg.c",    "system.c",
            "vce.c",    "vdc.c",
        },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildAtari8CartStd(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    a8_common_dir: []const u8,
    a8_cart_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_common_dir },
        .files = &.{"init-stack.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_cart_dir },
        .files = &.{"syms.s"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-data.c", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = a8_common_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_common_dir },
        .files = &.{ "putchar.c", "getchar.c" },
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = a8_common_dir },
        .files = &.{
            "close.s",        "fdtab.s",     "fdtable.s", "fdtoiocb.s",
            "findfreeiocb.s", "getfd.s",     "open.s",    "oserror.s",
            "rwcommon.s",     "sysremove.s", "write.s",
        },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildEater(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/crt0", .{plat_dir}) },
        .files = &.{ "reset.S", "serial.S", "systick.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S", "copy-data.c", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "delay.c", "getchar.c", "lcd.c", "putchar.c" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildGeosCbm(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "crt0.c", "geos_crt.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S", "copy-zp-data.c", "zero-bss.c" },
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/../c", .{crt0_dir}) },
        .files = &.{"mem.c"},
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildC128(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    comm_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const c64_dir = b.fmt("{s}/../c64", .{plat_dir});
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "basic-header.S", "init-mmu.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"init-stack.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = c64_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = comm_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "c128.c", "devnum.s", "kernal.S" },
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = comm_dir },
        .files = &.{ "abort.c", "cbm_k_bsout.c", "cbm_k_chrout.c", "chrout.c", "char-conv.c", "getchar.c", "putchar.c" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildPet(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    comm_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{"basic-header.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"init-stack.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = comm_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "devnum.s", "kernal.S" },
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = comm_dir },
        .files = &.{ "abort.c", "cbm_k_bsout.c", "cbm_k_chrout.c", "chrout.c", "char-conv.c", "getchar.c", "putchar.c" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildVic20(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    comm_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "basic-header.S", "init-stack-memtop.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = comm_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "devnum.s", "kernal.S" },
    });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = comm_dir },
        .files = &.{ "abort.c", "cbm_k_bsout.c", "cbm_k_chrout.c", "chrout.c", "char-conv.c", "getchar.c", "putchar.c" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildRp6502(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "init-cpu.s", "exit.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "init-stack.S", "copy-zp-data.c", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-custom.S"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{
            "abort.c",         "chdir.c",         "clock_getres.c",
            "clock_gettime.c", "clock_settime.c", "clock.c",
            "close.c",         "code_page.c",     "errno.s",
            "f_chdrive.c",     "f_chmod.c",       "f_closedir.c",
            "f_getcwd.c",      "f_getfree.c",     "f_getlabel.c",
            "f_lseek.c",       "f_mkdir.c",       "f_opendir.c",
            "f_readdir.c",     "f_rewinddir.c",   "f_seekdir.c",
            "f_setlabel.c",    "f_stat.c",        "f_telldir.c",
            "f_utime.c",       "getchar.c",       "lrand.c",
            "lseek.c",         "open.c",          "phi2.c",
            "putchar.c",       "read_xram.c",     "read_xstack.c",
            "read.c",          "remove.c",        "rename.c",
            "ria.s",           "stdin_opt.c",     "syncfs.c",
            "write_xram.c",    "write_xstack.c",  "write.c",
            "xregn.c",
        },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildRpc8e(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-zp-data.c", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/librpc8e/include", .{plat_dir}) });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/librpc8e/src", .{plat_dir}) },
        .files = &.{ "display.c", "drive.c", "mmu.c", "sortron.c" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildSupervision(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{"crt0.c"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-data.c", "init-stack.S", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "supervision.c", "supervision.s" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildDodo(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{"crt0.s"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-zp-data.c", "zero-bss.c", "init-stack.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{"api.s"},
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildOsiC1p(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{"crt0.s"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-data.c", "init-stack.S", "zero-bss.c" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "abort.c", "putchar.cc", "getchar.c", "kbhit.s" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildCpm65(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    // CP/M-65 exit is via BDOS; no exit handler in crt0.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "init-stack.S", "copy-zp-data.c", "zero-bss.c" },
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{ "cpm.S", "cpm-wrappers.c", "bios.S", "pblock.S", "putchar.c", "stack.S", "registers.S" },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildFds(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    nes_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    // FDS PARENT is nes; crt0 inherits NES crt0.S/init-stack.S + fds/reset.s.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{"reset.s"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = plat_dir },
        .files = &.{
            "bios.s",
            "fds_bios_AdjustFileCount.s",
            "fds_bios_AppendFile.s",
            "fds_bios_CheckDiskHeader.c",
            "fds_bios_CheckFileCount.s",
            "fds_bios_Delay131.c",
            "fds_bios_Delayms.s",
            "fds_bios_DisObj.c",
            "fds_bios_DisPF.c",
            "fds_bios_DisPFObj.c",
            "fds_bios_EnObj.c",
            "fds_bios_EnPF.c",
            "fds_bios_EnPFObj.c",
            "fds_bios_FileMatchTest.c",
            "fds_bios_GetDiskInfo.s",
            "fds_bios_GetNumFiles.c",
            "fds_bios_LoadFiles.s",
            "fds_bios_MemFill.s",
            "fds_bios_Nam2PixelConv.c",
            "fds_bios_OrPads.c",
            "fds_bios_Pixel2NamConv.c",
            "fds_bios_ReadDownExpPads.c",
            "fds_bios_ReadDownPads.c",
            "fds_bios_ReadDownVerifyPads.c",
            "fds_bios_ReadKeyboard.s",
            "fds_bios_ReadOrDownPads.c",
            "fds_bios_ReadOrDownVerifyPads.c",
            "fds_bios_ReadPads.c",
            "fds_bios_SetFileCount.s",
            "fds_bios_SetFileCount1.s",
            "fds_bios_SetNumFiles.c",
            "fds_bios_SkipFiles.c",
            "fds_bios_SpriteDMA.c",
            "fds_bios_UploadObject.c",
            "fds_bios_VINTWait.c",
            "fds_bios_VRAMFill.s",
            "fds_bios_WriteFile.s",
            "irq.c",
            "irq.s",
            "mapper.c",
        },
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

fn buildPceCd(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    libcrt: *std.Build.Step.Compile,
    plat_dir: []const u8,
    pce_common_dir: []const u8,
    crt0_dir: []const u8,
    com_inc: []const u8,
    com_asm: []const u8,
) Libs {
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.lto = .none;
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/crt0", .{plat_dir}) },
        .files = &.{ "copy-zp-data.S", "zero-bss.S", "zero-zp-bss.S" },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = crt0_dir },
        .files = &.{"init-stack.S"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/libpce/include", .{plat_dir}) });
    libc.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/libpce/include", .{pce_common_dir}) });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root = .{ .cwd_relative = b.fmt("{s}/libpce/src/cd", .{plat_dir}) },
        .files = &.{"bios.c"},
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

// ── Standalone entry point ────────────────────────────────────────────────────

pub fn build(b: *std.Build) void {
    const sdk_root = b.build_root.path orelse ".";
    const filter = b.option([]const u8, "platform", "Build only this platform (sim, mega65, c64, nes, neo6502, atari2600-4k, atari8-dos)");

    for ([_]Platform{
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
        .{ .name = "atari2600-3e", .query = .{ .cpu_arch = .mos, .os_tag = .atari2600 } },
        .{ .name = "atari5200-supercart", .query = .{ .cpu_arch = .mos, .os_tag = .atari5200 } },
        .{ .name = "atari8-cart-std", .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
        .{ .name = "snes", .query = .{ .cpu_arch = .mos, .os_tag = .snes } },
        .{ .name = "eater", .query = .{ .cpu_arch = .mos, .os_tag = .eater } },
        .{ .name = "geos-cbm", .query = .{ .cpu_arch = .mos, .os_tag = .geos_cbm } },
        .{ .name = "c128", .query = .{ .cpu_arch = .mos, .os_tag = .c128 } },
        .{ .name = "pet", .query = .{ .cpu_arch = .mos, .os_tag = .pet } },
        .{ .name = "vic20", .query = .{ .cpu_arch = .mos, .os_tag = .vic20 } },
        .{ .name = "rp6502", .query = .{ .cpu_arch = .mos, .os_tag = .rp6502 } },
        .{ .name = "rpc8e", .query = .{ .cpu_arch = .mos, .os_tag = .rpc8e } },
        .{ .name = "supervision", .query = .{ .cpu_arch = .mos, .os_tag = .supervision } },
        .{ .name = "dodo", .query = .{ .cpu_arch = .mos, .os_tag = .dodo } },
        .{ .name = "osi-c1p", .query = .{ .cpu_arch = .mos, .os_tag = .osi_c1p } },
        .{ .name = "cpm65", .query = .{ .cpu_arch = .mos, .os_tag = .cpm65 } },
        .{ .name = "fds", .query = .{ .cpu_arch = .mos, .os_tag = .fds } },
        .{ .name = "pce-cd", .query = .{ .cpu_arch = .mos, .os_tag = .pce_cd } },
    }) |pd| {
        if (filter) |f| if (!std.mem.eql(u8, f, pd.name)) continue;
        const libs = buildPlatform(b, sdk_root, pd, .ReleaseFast);
        installLib(b, libs.crt, pd.name);
        installLib(b, libs.crt0, pd.name);
        installLib(b, libs.c, pd.name);
        if (libs.neslib) |l| installLib(b, l, pd.name);
        if (libs.nesdoug) |l| installLib(b, l, pd.name);
        if (libs.nes_c) |l| installLib(b, l, pd.name);
    }
}

fn addLib(b: *std.Build, name: []const u8, target: std.Build.ResolvedTarget, opt: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{ .name = name, .linkage = .static, .root_module = b.createModule(.{ .target = target, .optimize = opt, .sanitize_c = .off }) });
    // Match prebuilt llvm-mos-sdk behaviour: libraries were built with LTO enabled.
    // Startup libs (libcrt0, libnes_c_startup) override this with lto = .none after creation.
    lib.lto = .full;
    return lib;
}

fn installLib(b: *std.Build, lib: *std.Build.Step.Compile, platform: []const u8) void {
    const dest = b.fmt("mos-platform/{s}/lib", .{platform});
    b.getInstallStep().dependOn(&b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = .{ .custom = dest } } }).step);
}
