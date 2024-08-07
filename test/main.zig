const std = @import("std");
const dirtstache = @import("dirtstache");
const TestSuite = @import("TestSuite.zig");

const TestSuiteType = enum {
    comments,
    delimiters,
    interpolation,
    inverted,
    partials,
    sections,
    dynamic_names,
    inheritance,
    lambdas,
};

const Options = struct {
    verbose: bool = false,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);

    var options = Options{};

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--verbose")) {
            options.verbose = true;
            continue;
        }
    }

    try runTestSuite(allocator, .comments, options);
}

fn runTestSuite(allocator: std.mem.Allocator, comptime suite: TestSuiteType, options: Options) !void {
    _ = options;

    const suite_name = @tagName(suite);
    const path = "test/mustache-spec/specs/" ++ suite_name ++ ".json";

    std.debug.print("Testing {s}...\n", .{suite_name});

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_data = try file.readToEndAlloc(allocator, 1024 * 1024 * 1024);
    const test_suite = try std.json.parseFromSliceLeaky(TestSuite, allocator, file_data, .{ .ignore_unknown_fields = true });

    for (test_suite.tests) |case| {
        const actual = try dirtstache.Renderer.renderSlice(allocator, case.template, .{});
        std.debug.print("\n{s}", .{case.name});
        std.testing.expectEqualStrings(case.expected, actual) catch {};
    }

    std.debug.print("\n", .{});
}
