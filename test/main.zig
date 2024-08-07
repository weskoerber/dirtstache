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

    try runTestSuite(allocator, .comments);
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

    var passed: usize = 0;
    for (test_suite.tests) |case| {
        const actual = try dirtstache.Renderer.renderSlice(allocator, case.template, .{});
        std.debug.print("\n{s}", .{case.name});
        if (std.testing.expectEqualStrings(case.expected, actual)) {
            passed += 1;
        } else |_| {}
    }

    std.debug.print("\n\nPassed {d}/{d}\n", .{ passed, test_suite.tests.len });
}
