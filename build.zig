pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run unit tests");

    const dirtstache = b.addModule("dirtstache", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_exe = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_exe.root_module.addImport("dirtstache", dirtstache);

    const run_test_exe = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_test_exe.step);
}

const std = @import("std");
