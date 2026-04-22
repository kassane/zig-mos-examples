const std = @import("std");

pub fn build(b: *std.Build) void {
    const sdk = b.option([]const u8, "sdk", "Path to llvm-mos-sdk") orelse
        std.fs.path.resolve(b.allocator, &.{
            b.build_root.path orelse ".",
            "../../../llvm-mos-sdk",
        }) catch @panic("cannot resolve sdk path");

    const mega65_libc = b.option([]const u8, "mega65-libc", "Path to mega65-libc checkout") orelse {
        std.log.warn("mega65-hello: skipping (pass -Dmega65-libc=<path> to build)", .{});
        return;
    };

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mos45gs02 },
    });

    const mega65_mod = blk: {
        const tc = b.addTranslateC(.{
            .root_source_file = .{ .cwd_relative = b.fmt("{s}/mos-platform/mega65/include/mega65.h", .{sdk}) },
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = false,
        });
        tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/mega65/include", .{sdk}) });
        tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/c64/include", .{sdk}) });
        tc.addIncludePath(.{ .cwd_relative = b.fmt("{s}/mos-platform/common/include", .{sdk}) });
        break :blk tc.createModule();
    };

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
        .name = "hello",
        .root_module = b.createModule(.{
            .root_source_file = b.path("hello.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    exe.bundle_compiler_rt = false;
    exe.root_module.addImport("mega65", mega65_mod);
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

    const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello.prg" });
    b.getInstallStep().dependOn(&install.step);
}
