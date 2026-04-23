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
    libcrt.root_module.addIncludePath(.{ .cwd_relative = crt_dir });
    libcrt.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt_dir },
        .files = &.{ "const.S", "call-indir.S", "divmod.cc", "divmod-large.cc", "mul.cc", "shift.cc", "rotate.cc" },
        .flags = &.{},
    });

    if (std.mem.eql(u8, pd.name, "nes"))
        return buildNes(b, target, opt, libcrt, plat_dir, crt0_dir, com_inc, com_asm);
    if (std.mem.startsWith(u8, pd.name, "nes-"))
        return buildNes(b, target, opt, libcrt, b.fmt("{s}/mos-platform/nes", .{sdk_root}), crt0_dir, com_inc, com_asm);
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
    if (std.mem.eql(u8, pd.name, "atari8-dos")) {
        const a8_common_dir = b.fmt("{s}/mos-platform/atari8-common", .{sdk_root});
        const a8_dos_dir    = b.fmt("{s}/mos-platform/atari8-dos",    .{sdk_root});
        return buildAtari8Dos(b, target, opt, libcrt, a8_common_dir, a8_dos_dir, crt0_dir, com_inc, com_asm);
    }
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

    // libcrt0 — startup: stack init + data copy + exit handler.
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
        .flags = &.{},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{"copy-zp-data.c"},
        .flags = &.{"-fno-lto"},
    });
    const exit_file: []const u8 = if (std.mem.eql(u8, pd.name, "sim")) "exit-custom.S" else "exit-loop.c";
    const exit_flags: []const []const u8 = if (std.mem.eql(u8, pd.name, "sim")) &.{} else &.{"-fno-lto"};
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{exit_file},
        .flags = exit_flags,
    });

    // libc — platform I/O and kernal wrappers.
    const libc = addLib(b, "c", target, opt);
    if (std.mem.eql(u8, pd.name, "sim")) {
        libc.root_module.addIncludePath(.{ .cwd_relative = plat_dir });
        libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
        libc.root_module.addCSourceFiles(.{
            .root  = .{ .cwd_relative = plat_dir },
            .files = &.{ "putchar.c", "stdlib.c", "sim-io.c" },
            .flags = &.{},
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
            .root  = .{ .cwd_relative = plat_dir },
            .files = asm_files,
            .flags = &.{},
        });
        libc.root_module.addCSourceFiles(.{
            .root  = .{ .cwd_relative = comm_dir },
            .files = &.{ "abort.c", "cbm_k_bsout.c", "cbm_k_chrout.c", "chrout.c", "char-conv.c" },
            .flags = &.{},
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
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
        .flags = &.{},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-data.c", "copy-zp-data.c", "zero-bss.c", "zero-zp-bss.c" },
        .flags = &.{"-fno-lto"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = &.{"-fno-lto"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = nes_dir },
        .files = &.{"crt0.c"},
        .flags = &.{},
    });

    // libc (nes-c) — putchar + rompoke.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = nes_dir },
        .files = &.{"putchar.c"},
        .flags = &.{},
    });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/rompoke", .{nes_dir}) },
        .files = &.{"rompoke.c"},
        .flags = &.{},
    });

    // libneslib.
    const libneslib = addLib(b, "neslib", target, opt);
    libneslib.root_module.addIncludePath(.{ .cwd_relative = neslib_dir });
    libneslib.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libneslib.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libneslib.root_module.addIncludePath(.{ .cwd_relative = com_inc });
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
        .flags = &.{},
    });

    // libnesdoug.
    const libnesdoug = addLib(b, "nesdoug", target, opt);
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = nesdoug_dir });
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = neslib_dir });
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = nes_dir });
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libnesdoug.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libnesdoug.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = nesdoug_dir },
        .files = &.{
            "metatile.c",       "metatile.s",
            "nesdoug.c",        "nesdoug.s",
            "padlib.s",
            "vram_buffer.c",    "vram_buffer.s",
            "vram_buffer_ops.s","zaplib.s",
        },
        .flags = &.{},
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
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "crt0.S", "init-stack.S" },
        .flags = &.{},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{"copy-zp-data.c"},
        .flags = &.{"-fno-lto"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = &.{"-fno-lto"},
    });

    // libc (neo6502-c) — API + platform I/O.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/api", .{neo_dir}) });
    libc.root_module.addIncludePath(.{ .cwd_relative = neo_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/api", .{neo_dir}) },
        .files = &.{
            "api-internal.c", "console.c",    "controller.c", "file.c",
            "graphics.c",     "sound.c",      "sprites.c",    "system.c",
            "turtle.c",       "uext.c",       "mouse.c",
        },
        .flags = &.{},
    });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = neo_dir },
        .files = &.{ "char-conv.c", "clock.c", "getchar.c", "putchar.c" },
        .flags = &.{},
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
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
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-zp-data.c", "copy-data.c" },
        .flags = &.{"-fno-lto"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = &.{"-fno-lto"},
    });

    // libc: frameloop + vcslib.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = a26_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a26_dir },
        .files = &.{ "frameloop.c", "vcslib.S" },
        .flags = &.{},
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
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a8_common_dir },
        .files = &.{"init-stack.S"},
        .flags = &.{},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a8_dos_dir },
        .files = &.{"_Exit.c"},
        .flags = &.{},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-zp-data.c", "zero-bss.c" },
        .flags = &.{"-fno-lto"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-custom.S"},
        .flags = &.{},
    });

    // libc: atari8 I/O.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = a8_common_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a8_common_dir },
        .files = &.{ "putchar.c", "getchar.c" },
        .flags = &.{},
    });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a8_common_dir },
        .files = &.{
            "close.s",       "fdtab.s",      "fdtable.s",    "fdtoiocb.s",
            "findfreeiocb.s","getfd.s",       "open.s",       "oserror.s",
            "rwcommon.s",    "sysremove.s",   "write.s",
        },
        .flags = &.{},
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
    const cpu_flag = "-mcpu=mosw65c02";
    const cx16_def = "-D__CX16__";

    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "init-stack.S", "copy-zp-data.c", "zero-bss.c" },
        .flags = &.{ "-fno-lto", cpu_flag, cx16_def },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-return.c"},
        .flags = &.{ "-fno-lto", cpu_flag, cx16_def },
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = cx16_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = comm_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = cx16_dir },
        .files = &.{
            "kernal.S",
            "cx16_k_bsave.s",
            "cx16_k_clock_get_date_time.s", "cx16_k_clock_set_date_time.s",
            "cx16_k_console_get_char.s",    "cx16_k_console_init.s",
            "cx16_k_console_put_char.s",    "cx16_k_console_put_image.s",
            "cx16_k_console_set_paging_message.s",
            "cx16_k_enter_basic.s",         "cx16_k_entropy_get.s",
            "cx16_k_fb_cursor_next_line.s", "cx16_k_fb_cursor_position.s",
            "cx16_k_fb_fill_pixels.s",      "cx16_k_fb_filter_pixels.s",
            "cx16_k_fb_get_info.s",         "cx16_k_fb_get_pixel.s",
            "cx16_k_fb_get_pixels.s",       "cx16_k_fb_init.s",
            "cx16_k_fb_move_pixels.s",
            "cx16_k_fb_set_8_pixels.s",     "cx16_k_fb_set_8_pixels_opaque.s",
            "cx16_k_fb_set_palette.s",
            "cx16_k_graph_clear.s",         "cx16_k_graph_draw_image.s",
            "cx16_k_graph_draw_line.s",     "cx16_k_graph_draw_oval.s",
            "cx16_k_graph_draw_rect.s",     "cx16_k_graph_get_char_size.s",
            "cx16_k_graph_init.s",          "cx16_k_graph_move_rect.s",
            "cx16_k_graph_put_char.s",      "cx16_k_graph_set_colors.s",
            "cx16_k_graph_set_font.s",      "cx16_k_graph_set_window.s",
            "cx16_k_i2c_read_byte.s",       "cx16_k_i2c_write_byte.s",
            "cx16_k_joystick_get.c",
            "cx16_k_joystick_scan.s",       "cx16_k_kbdbuf_get_modifiers.s",
            "cx16_k_kbdbuf_peek.s",         "cx16_k_kbdbuf_put.s",
            "cx16_k_keymap_get_id.s",       "cx16_k_keymap_set.s",
            "cx16_k_macptr.s",
            "cx16_k_memory_copy.s",         "cx16_k_memory_crc.s",
            "cx16_k_memory_decompress.s",   "cx16_k_memory_fill.s",
            "cx16_k_monitor.s",
            "cx16_k_mouse_config.s",        "cx16_k_mouse_get.s",
            "cx16_k_mouse_scan.s",          "cx16_k_rdtim.s",
            "cx16_k_screen_mode_get.s",     "cx16_k_screen_mode_set.s",
            "cx16_k_screen_set_charset.s",
            "cx16_k_sprite_set_image.s",    "cx16_k_sprite_set_position.s",
            "filevars.s",
            "get_numbanks.s", "get_ostype.s", "get_tv.s", "set_tv.s",
            "vera_layer_enable.s",          "vera_sprites_enable.s",
            "videomode.s",                  "vpeek.s",
            "vpoke.s",                      "waitvsync.s",
            "char-conv.c",
        },
        .flags = &.{ cpu_flag, cx16_def },
    });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = comm_dir },
        .files = &.{
            "abort.c",       "putchar.c",       "getchar.c",
            "cbm_k_bsout.c", "cbm_k_chrout.c",  "chrout.c",
            "cbm_k_getin.c",
        },
        .flags = &.{ cpu_flag, cx16_def },
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
    const cpu_flag = "-mcpu=mosw65c02";

    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "init-stack.S", "copy-zp-data.c", "zero-bss.c" },
        .flags = &.{ "-fno-lto", cpu_flag },
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = &.{ "-fno-lto", cpu_flag },
    });

    // lynx-c has no source files — emit a tiny stub so the static archive isn't empty.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = lynx_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    const stub_wf = b.addWriteFiles();
    const stub_c = stub_wf.add("lynx_stub.c", "// lynx-c stub — no platform sources required.\nstatic int lynx_stub_marker;\n");
    libc.root_module.addCSourceFile(.{ .file = stub_c, .flags = &.{cpu_flag} });

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
    const cpu_flag = "-mcpu=moshuc6280";

    // libcrt0: pce-specific crt0 files + common init-stack + exit-loop.
    // Note: crt0/crt0.S is a standalone object added per-exe (not in this lib).
    const libcrt0 = addLib(b, "crt0", target, opt);
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = pce_common_dir });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{"init-stack.S"},
        .flags = &.{cpu_flag},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/crt0", .{pce_dir}) },
        .files = &.{
            "copy-data.S", "copy-zp-data.S",
            "irq.S",
            "zero-bss.S",  "zero-zp-bss.S",
        },
        .flags = &.{cpu_flag},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = &.{ "-fno-lto", cpu_flag },
    });

    // libc: pce-common libpce hardware library.
    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = libpce_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = pce_common_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = libpce_src },
        .files = &.{
            "bank.S", "bank-c.c",
            "joypad.c",
            "memory.S",
            "psg.c",
            "system.c",
            "vce.c",
            "vdc.c",
        },
        .flags = &.{cpu_flag},
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
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libcrt0.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a8_common_dir },
        .files = &.{"init-stack.S"},
        .flags = &.{},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a8_cart_dir },
        .files = &.{"syms.s"},
        .flags = &.{},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = crt0_dir },
        .files = &.{ "copy-data.c", "zero-bss.c" },
        .flags = &.{"-fno-lto"},
    });
    libcrt0.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = b.fmt("{s}/exit", .{crt0_dir}) },
        .files = &.{"exit-loop.c"},
        .flags = &.{"-fno-lto"},
    });

    const libc = addLib(b, "c", target, opt);
    libc.root_module.addIncludePath(.{ .cwd_relative = a8_common_dir });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_inc });
    libc.root_module.addIncludePath(.{ .cwd_relative = com_asm });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a8_common_dir },
        .files = &.{ "putchar.c", "getchar.c" },
        .flags = &.{},
    });
    libc.root_module.addCSourceFiles(.{
        .root  = .{ .cwd_relative = a8_common_dir },
        .files = &.{
            "close.s", "fdtab.s", "fdtable.s", "fdtoiocb.s",
            "findfreeiocb.s", "getfd.s", "open.s", "oserror.s",
            "rwcommon.s", "sysremove.s", "write.s",
        },
        .flags = &.{},
    });

    return .{ .crt = libcrt, .crt0 = libcrt0, .c = libc };
}

// ── Standalone entry point ────────────────────────────────────────────────────

pub fn build(b: *std.Build) void {
    const sdk_root = b.build_root.path orelse ".";
    const filter   = b.option([]const u8, "platform", "Build only this platform (sim, mega65, c64, nes, neo6502, atari2600-4k, atari8-dos)");

    for ([_]Platform{
        .{ .name = "sim",         .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 } } },
        .{ .name = "mega65",      .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos45gs02 } } },
        .{ .name = "c64",         .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502 } } },
        .{ .name = "nes",         .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "neo6502",     .query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 } } },
        .{ .name = "atari2600-4k",.query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502x } } },
        .{ .name = "atari8-dos",  .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
        .{ .name = "cx16",        .query = .{ .cpu_arch = .mos, .os_tag = .cx16, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 } } },
        .{ .name = "lynx-bll",    .query = .{ .cpu_arch = .mos, .os_tag = .lynx, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 } } },
        .{ .name = "pce",         .query = .{ .cpu_arch = .mos, .os_tag = .pce, .cpu_model = .{ .explicit = &std.Target.mos.cpu.moshuc6280 } } },
        .{ .name = "nes-cnrom",   .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-unrom",   .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "nes-mmc1",    .query = .{ .cpu_arch = .mos, .os_tag = .nes } },
        .{ .name = "atari2600-3e",.query = .{ .cpu_arch = .mos, .os_tag = .freestanding, .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos6502x } } },
        .{ .name = "atari8-cart-std", .query = .{ .cpu_arch = .mos, .os_tag = .atari8 } },
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
