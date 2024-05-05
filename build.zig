const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .mos,
            .os_tag = .freestanding,
            .abi = .none,
        },
    });

    const examples = &.{
        "hello1",
    };

    inline for (examples) |example| {
        buildExamples(b, .{
            .name = example,
            .target = target,
            .optimize = optimize,
            .src = &.{
                "nesdoug/" ++ example ++ "/" ++ example ++ ".zig",
                "nesdoug/" ++ example ++ "/chr-rom.s",
            },
        });
    }
}
fn buildExamples(b: *std.Build, options: struct {
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    src: []const []const u8,
}) void {
    const lib = b.addStaticLibrary(.{
        .name = options.name,
        .target = options.target,
        .optimize = options.optimize,
    });
    for (options.src) |src_file| {
        if (std.mem.endsWith(u8, src_file, ".s"))
            lib.addAssemblyFile(b.path(src_file))
        else if (std.mem.endsWith(u8, src_file, ".c"))
            lib.addCSourceFiles(.{
                .files = &.{src_file},
                .flags = &.{},
            })
        else
            lib.root_module.root_source_file = b.path(src_file);
    }
    const neslib = b.addModule("neslib", .{
        .root_source_file = b.path("bindings/neslib.zig"),
    });
    lib.root_module.addImport("neslib", neslib);
    b.installArtifact(lib);
}
