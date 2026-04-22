const std = @import("std");

pub fn build(b: *std.Build) void {
    const sdk = b.option([]const u8, "sdk", "Path to llvm-mos-sdk") orelse
        std.fs.path.resolve(b.allocator, &.{
            b.build_root.path orelse ".",
            "../../llvm-mos-sdk",
        }) catch @panic("cannot resolve sdk path");

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .mos,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.mos.cpu.mosw65c02 },
    });

    const wf = b.addWriteFiles();
    const libc_txt = wf.add("libc.txt", b.fmt(
        "include_dir={s}/mos-platform/neo6502/include\n" ++
        "sys_include_dir={s}/mos-platform/common/include\n" ++
        "crt_dir={s}/mos-platform/neo6502/lib\n" ++
        "msvc_lib_dir=\n" ++
        "kernel32_lib_dir=\n" ++
        "gcc_dir=\n",
        .{ sdk, sdk, sdk }
    ));

    const wf2 = b.addWriteFiles();
    const wrapper_ld = wf2.add("neo6502-wrapper.ld", b.fmt(
        \\SEARCH_DIR("{s}/mos-platform/neo6502/lib");
        \\SEARCH_DIR("{s}/mos-platform/common/lib");
        \\INCLUDE "{s}/mos-platform/neo6502/lib/link.ld"
    , .{ sdk, sdk, sdk }));

    const exe = b.addExecutable(.{
        .name = "graphics",
        .root_module = b.createModule(.{
            .root_source_file = b.path("graphics.zig"),
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

    const install = b.addInstallArtifact(exe, .{ .dest_sub_path = "graphics.neo" });
    b.getInstallStep().dependOn(&install.step);
}
