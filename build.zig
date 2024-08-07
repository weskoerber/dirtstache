pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run unit tests");
    const integration_step = b.step("integration", "Run integration tests against mustache spec");

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

    const integration_exe = b.addExecutable(.{
        .name = "integration-tests",
        .root_source_file = b.path("test/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_integration_exe = b.addRunArtifact(integration_exe);
    integration_step.dependOn(&run_integration_exe.step);
    integration_exe.root_module.addImport("dirtstache", dirtstache);

    if (b.args) |args| {
        run_integration_exe.addArgs(args);
    }
}

const std = @import("std");
