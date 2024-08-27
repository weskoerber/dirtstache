pub fn renderSlice(allocator: Allocator, s: []const u8, comptime data: anytype) ![]const u8 {
    var dest = ArrayList(u8).init(allocator);
    const tokens = try Tokenizer.parseFromSlice(allocator, s);
    defer allocator.free(tokens);
    var prev_pos: usize = 0;

    for (tokens) |token| {
        try dest.appendSlice(s[prev_pos..token.start_pos]);

        const data_type = @TypeOf(data);
        const data_typeinfo = @typeInfo(data_type);

        switch (token.type) {
            .variable => {
                inline for (data_typeinfo.Struct.fields) |field| {
                    if (std.mem.eql(u8, token.getName(s), field.name)) {
                        const value = @field(data, field.name);
                        if (try formatValue(allocator, value)) |str| {
                            defer allocator.free(str);
                            try dest.appendSlice(str);
                        }
                    }
                }
            },
            .comment => {},
            else => @panic("TODO"),
        }

        prev_pos = token.end_pos + 1;
    }

    if (prev_pos < s.len) {
        try dest.appendSlice(s[prev_pos..s.len]);
    }

    return try dest.toOwnedSlice();
}

fn formatValue(allocator: Allocator, value: anytype) !?[]const u8 {
    return switch (@typeInfo(@TypeOf(value))) {
        .Bool => try fmt.allocPrint(allocator, "{s}", .{if (value) "true" else "false"}),
        .Int, .ComptimeInt => try fmt.allocPrint(allocator, "{d}", .{value}),
        .Float, .ComptimeFloat => try fmt.allocPrint(allocator, "{d}", .{value}),
        .Array => |a| if (a.child != u8) @panic("Pointer to " ++ @typeName(a.child) ++ " not allowed") else try fmt.allocPrint(allocator, "{s}", .{value}),
        .Pointer => |p| if (@typeInfo(p.child) != .Array) @panic("Pointer to " ++ @typeName(p.child) ++ " not allowed") else try fmt.allocPrint(allocator, "{s}", .{value}),
        .Null => null,
        else => @panic("TODO: Type '" ++ @typeName(@TypeOf(value)) ++ " not yet implemented"),
    };
}

const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Token = @import("Token.zig");
const Tokenizer = @import("Tokenizer.zig");

test "comment" {
    const str = "Hello, {{! test}}world!";
    const res = try renderSlice(testing.allocator, str, .{});
    defer testing.allocator.free(res);

    try testing.expectEqualStrings("Hello, world!", res);
}

test "variable - missing" {
    const str = "Hello, {{name}}!";
    const res = try renderSlice(testing.allocator, str, .{});
    defer testing.allocator.free(res);

    try testing.expectEqualStrings("Hello, !", res);
}

test "variable - string" {
    const str = "Hello, {{name}}!";
    const res = try renderSlice(testing.allocator, str, .{ .name = "world" });
    defer testing.allocator.free(res);

    try testing.expectEqualStrings("Hello, world!", res);
}

test "variable - integer" {
    const str = "Earned ${{currency}}!";
    const res = try renderSlice(testing.allocator, str, .{ .currency = 42 });
    defer testing.allocator.free(res);

    try testing.expectEqualStrings("Earned $42!", res);
}

test "variable - bool" {
    const str = "Online: {{is_online}}";
    const res = try renderSlice(testing.allocator, str, .{ .is_online = false });
    defer testing.allocator.free(res);

    try testing.expectEqualStrings("Online: false", res);
}

test "variable - float" {
    const str = "idk {{val}}";
    const res = try renderSlice(testing.allocator, str, .{ .val = 0.069 });
    defer testing.allocator.free(res);

    try testing.expectEqualStrings("idk 0.069", res);
}

test "variable - null" {
    const str = "I ({{cannot}}) be seen!";
    const res = try renderSlice(testing.allocator, str, .{ .cannot = null });
    defer testing.allocator.free(res);

    try testing.expectEqualStrings("I () be seen!", res);
}

const TestCase = struct {
    template: []const u8,
    expected: []const u8,
};

// Interpolation
test "interpolation" {
    const cases = [_]TestCase{
        .{ // 0
            .template = "Hello from {Mustache}!\n",
            .expected = "Hello from {Mustache}!\n",
        },
        .{ // 1
            .template = "Hello, {{subject}}!\n",
            .expected = "Hello, world!\n",
        },
        .{ // 2
            .template = "These characters should be HTML escaped: {{forbidden}}\n",
            .expected = "These characters should be HTML escaped: &amp; &quot; &lt; &gt;\n",
        },
        .{ // 3
            .template = "These characters should not be HTML escaped: {{{forbidden}}}\n",
            .expected = "These characters should not be HTML escaped: & \" < >\n",
        },
        .{ // 4
            .template = "These characters should not be HTML escaped: {{&forbidden}}\n",
            .expected = "These characters should not be HTML escaped: & \" < >\n",
        },
        .{ // 5
            .template = "\"{{mph}} miles an hour!\"",
            .expected = "\"85 miles an hour!\"",
        },
        .{ // 6
            .template = "\"{{{mph}}} miles an hour!\"",
            .expected = "\"85 miles an hour!\"",
        },
        .{ // 7
            .template = "\"{{&mph}} miles an hour!\"",
            .expected = "\"85 miles an hour!\"",
        },
        .{ // 8
            .template = "\"{{power}} jiggawatts!\"",
            .expected = "\"1.21 jiggawatts!\"",
        },
        .{ // 9
            .template = "\"{{{power}}} jiggawatts!\"",
            .expected = "\"1.21 jiggawatts!\"",
        },
        .{ // 10
            .template = "\"{{&power}} jiggawatts!\"",
            .expected = "\"1.21 jiggawatts!\"",
        },
        .{ // 11
            .template = "I ({{cannot}}) be seen!",
            .expected = "I () be seen!",
        },
        .{ // 12
            .template = "I ({{{cannot}}}) be seen!",
            .expected = "I () be seen!",
        },
        .{ // 13
            .template = "I ({{&cannot}}) be seen!",
            .expected = "I () be seen!",
        },
        .{ // 14
            .template = "I ({{cannot}}) be seen!",
            .expected = "I () be seen!",
        },
        .{ // 15
            .template = "I ({{{cannot}}}) be seen!",
            .expected = "I () be seen!",
        },
        .{ // 16
            .template = "I ({{&cannot}}) be seen!",
            .expected = "I () be seen!",
        },
        .{ // 17
            .template = "\"{{person.name}}\" == \"{{#person}}{{name}}{{/person}}\"",
            .expected = "\"Joe\" == \"Joe\"",
        },
        .{ // 18
            .template = "\"{{{person.name}}}\" == \"{{#person}}{{{name}}}{{/person}}\"",
            .expected = "\"Joe\" == \"Joe\"",
        },
        .{ // 19
            .template = "\"{{&person.name}}\" == \"{{#person}}{{&name}}{{/person}}\"",
            .expected = "\"Joe\" == \"Joe\"",
        },
        .{ // 20
            .template = "\"{{a.b.c.d.e.name}}\" == \"Phil\"",
            .expected = "\"Phil\" == \"Phil\"",
        },
        .{ // 21
            .template = "\"{{a.b.c}}\" == \"\"",
            .expected = "\"\" == \"\"",
        },
        .{ // 22
            .template = "\"{{a.b.c.name}}\" == \"\"",
            .expected = "\"\" == \"\"",
        },
        .{ // 23
            .template = "\"{{#a}}{{b.c.d.e.name}}{{/a}}\" == \"Phil\"",
            .expected = "\"Phil\" == \"Phil\"",
        },
        .{ // 24
            .template = "{{#a}}{{b.c}}{{/a}}",
            .expected = "",
        },
        .{ // 25
            .template = "Hello, {{.}}!\n",
            .expected = "Hello, world!\n",
        },
        .{ // 26
            .template = "These characters should be HTML escaped: {{.}}\n",
            .expected = "These characters should be HTML escaped: &amp; &quot; &lt; &gt;\n",
        },
        .{ // 27
            .template = "These characters should not be HTML escaped: {{{.}}}\n",
            .expected = "These characters should not be HTML escaped: & \" < >\n",
        },
        .{ // 28
            .template = "These characters should not be HTML escaped: {{&.}}\n",
            .expected = "These characters should not be HTML escaped: & \" < >\n",
        },
        .{ // 29
            .template = "\"{{.}} miles an hour!\"",
            .expected = "\"85 miles an hour!\"",
        },
        .{ // 30
            .template = "| {{string}} |",
            .expected = "| --- |",
        },
        .{ // 31
            .template = "| {{{string}}} |",
            .expected = "| --- |",
        },
        .{ // 32
            .template = "| {{&string}} |",
            .expected = "| --- |",
        },
        .{ // 33
            .template = "  {{string}}\n",
            .expected = "  ---\n",
        },
        .{ // 34
            .template = "  {{{string}}}\n",
            .expected = "  ---\n",
        },
        .{ // 35
            .template = "  {{&string}}\n",
            .expected = "  ---\n",
        },
        .{ // 36
            .template = "|{{ string }}|",
            .expected = "|---|",
        },
        .{ // 37
            .template = "|{{{ string }}}|",
            .expected = "|---|",
        },
        .{ // 38
            .template = "|{{& string }}|",
            .expected = "|---|",
        },
    };

    try testCase(cases[0], .{});
    try testCase(cases[1], .{ .subject = "world" });
    // try testCase(cases[2], .{ .forbidden = "& \" < >" });
    // try testCase(cases[3], .{ .forbidden = "& \" < >" });
    // try testCase(cases[4], .{ .forbidden = "& \" < >" });
    try testCase(cases[5], .{ .mph = 85 });
    // try testCase(cases[6], .{ .mph = 85 });
    // try testCase(cases[7], .{ .mph = 85 });
    try testCase(cases[8], .{ .power = 1.21 });
    // try testCase(cases[9], .{ .power = 1.21 });
    // try testCase(cases[9], .{ .power = 1.21 });
    // try testCase(cases[10], .{ .power = 1.21 });
    try testCase(cases[11], .{ .cannot = null });
    // try testCase(cases[12], .{ .cannot = null });
    // try testCase(cases[13], .{ .cannot = null });
    try testCase(cases[14], .{});
    // try testCase(cases[15], .{});
    // try testCase(cases[16], .{});
    // try testCase(cases[17], .{ .person = .{} });
    // try testCase(cases[18], .{ .person = .{} });
    // try testCase(cases[19], .{ .person = .{} });
    // try testCase(cases[20], .{ .a = .{ .b = .{ .c = .{ .d = .{ .e = .{ .name = "Phil" } } } } } });
    try testCase(cases[21], .{ .a = .{} });
    try testCase(cases[22], .{ .a = .{ .b = .{} }, .c = .{ .name = "Jim" } });
    // try testCase(cases[23], .{ .a = .{ .b = .{ .c = .{ .d = .{ .e = .{ .name = "Phil" } } } } }, .b = .{ .c = .{ .d = .{ .e = .{ .name = "Wrong" } } } } });
    // try testCase(cases[24], .{ .a = .{ .b = .{} }, .b = .{ .c = "ERROR" } });
    // try testCase(cases[25], .{"World"});
    // try testCase(cases[26], .{"& \" < >"});
    // try testCase(cases[27], .{"& \" < >"});
    // try testCase(cases[28], .{"& \" < >"});
    // try testCase(cases[29], .{85});
    try testCase(cases[30], .{ .string = "---" });
    // try testCase(cases[31], .{ .string = "---" });
    // try testCase(cases[32], .{ .string = "---" });
    try testCase(cases[33], .{ .string = "---" });
    // try testCase(cases[34], .{ .string = "---" });
    // try testCase(cases[35], .{ .string = "---" });
    try testCase(cases[36], .{ .string = "---" });
    // try testCase(cases[37], .{ .string = "---" });
    // try testCase(cases[38], .{ .string = "---" });
}

fn testCase(case: TestCase, data: anytype) !void {
    const actual = try renderSlice(testing.allocator, case.template, data);
    defer testing.allocator.free(actual);

    try testing.expectEqualStrings(case.expected, actual);
}
