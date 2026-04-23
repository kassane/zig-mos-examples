// Copyright (c) 2024 Matheus C. França
// SPDX-License-Identifier: Apache-2.0
const std = @import("std");

pub fn build(b: *std.Build) void {
    const sdk = b.option([]const u8, "sdk", "Path to llvm-mos-sdk") orelse
        std.fs.path.resolve(b.allocator, &.{
            b.build_root.path orelse ".",
            "../../../llvm-mos-sdk",
        }) catch @panic("cannot resolve sdk path");

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 },
    });

    const neslib_mod = blk: {
        const tc = b.addTranslateC(.{
            .root_source_file = .{ .cwd_relative = b.fmt("{s}/mos-platform/nes/include/neslib.h", .{sdk}) },
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = false,
        });
        tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/nes/include", .{sdk}) });
        tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/include", .{sdk}) });
        break :blk tc.createModule();
    };

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
        \\.incbin "{s}/Alpha.chr"
    , .{b.build_root.path orelse "."}));

    const exe = b.addExecutable(.{
        .name = "sprites",
        .root_module = b.createModule(.{
            .root_source_file = b.path("sprites.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.root_module.addImport("neslib", neslib_mod);
    exe.root_module.addAssemblyFile(chr_asm);
    exe.root_module.addObjectFile(.{ .cwd_relative = b.fmt("{s}/mos-platform/nes-nrom/lib/crt0.o", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/nes-nrom/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/nes/lib", .{sdk}) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/lib", .{sdk}) });
    exe.root_module.linkSystemLibrary("neslib", .{ .use_pkg_config = .no });
    exe.root_module.linkSystemLibrary("crt0", .{ .use_pkg_config = .no });
    exe.setLinkerScript(wrapper_ld);

    const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "sprites.nes" });
    b.getInstallStep().dependOn(&install.step);
}
