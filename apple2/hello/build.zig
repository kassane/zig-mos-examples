const std = @import("std");

pub fn build(b: *std.Build) void {
    const sdk = b.option([]const u8, "sdk", "Path to llvm-mos-sdk") orelse
        std.fs.path.resolve(b.allocator, &.{
            b.build_root.path orelse ".",
            "../../../llvm-mos-sdk",
        }) catch @panic("cannot resolve sdk path");

    const apple2_sdk = b.option([]const u8, "apple2-sdk", "Path to apple-ii-port-work checkout") orelse {
        std.log.warn("apple2-hello: skipping (pass -Dapple2-sdk=<path> to build)", .{});
        return;
    };

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
    });

    const lib_root = b.fmt("{s}/src/lib", .{apple2_sdk});

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/common/include\n" ++
        "sys_include_dir={s}/mos-platform/common/include\n" ++
        "crt_dir={s}/mos-platform/common/lib\n" ++
        "msvc_lib_dir=\n" ++
        "kernel32_lib_dir=\n" ++
        "gcc_dir=\n",
        .{ sdk, sdk, sdk }
    ));

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_module = b.createModule(.{
            .root_source_file = b.path("hello.zig"),
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

    const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "hello.sys" });
    b.getInstallStep().dependOn(&install.step);
}
