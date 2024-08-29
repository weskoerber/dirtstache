test "No Interpolation" {
    try testCase(
        "Hello from {Mustache}!\n",
        "Hello from {Mustache}!\n",
        .{},
    );
}

test "Basic Interpolation" {
    try testCase(
        "Hello, world!\n",
        "Hello, {{subject}}!\n",
        .{ .subject = "world" },
    );
}

test "No Re-interpolation" {
    try testCase(
        "{{planet}}: earth",
        "{{template}}: {{planet}}",
        .{ .template = "{{planet}}", .planet = "earth" },
    );
}

test "HTML Escaping" {
    try testCase(
        "These characters should be HTML escaped: &amp; &quot; &lt; &gt;\n",
        "These characters should be HTML escaped: {{forbidden}}\n",
        .{ .forbidden = "& \" < >" },
    );
}

test "Triple Mustache" {
    try testCase(
        "These characters should not be HTML escaped: & \" < >\n",
        "These characters should not be HTML escaped: {{{forbidden}}}\n",
        .{ .forbidden = "& \" < >" },
    );
}

test "Ampersand" {
    try testCase(
        "These characters should not be HTML escaped: & \" < >\n",
        "These characters should not be HTML escaped: {{&forbidden}}\n",
        .{ .forbidden = "& \" < >" },
    );
}

test "Basic Integer Interpolation" {
    try testCase(
        "\"85 miles an hour!\"",
        "\"{{mph}} miles an hour!\"",
        .{ .mph = 85 },
    );
}

test "Triple Mustache Integer Interpolation" {
    try testCase(
        "\"85 miles an hour!\"",
        "\"{{{mph}}} miles an hour!\"",
        .{ .mph = 85 },
    );
}
test "Ampersand Integer Interpolation" {
    try testCase(
        "\"85 miles an hour!\"",
        "\"{{&mph}} miles an hour!\"",
        .{ .mph = 85 },
    );
}

test "Basic Decimal Interpolation" {
    try testCase(
        "\"1.21 jiggawatts!\"",
        "\"{{power}} jiggawatts!\"",
        .{ .power = 1.21 },
    );
}

test "Triple Mustache Decimal Interpolation" {
    try testCase(
        "\"1.21 jiggawatts!\"",
        "\"{{{power}}} jiggawatts!\"",
        .{ .power = 1.21 },
    );
}

test "Ampersand Decimal Interpolation" {
    try testCase(
        "\"1.21 jiggawatts!\"",
        "\"{{&power}} jiggawatts!\"",
        .{ .power = 1.21 },
    );
}

test "Basic Null Interpolation" {
    try testCase(
        "I () be seen!",
        "I ({{cannot}}) be seen!",
        .{ .cannot = null },
    );
}

test "Triple Mustache Null Interpolation" {
    try testCase(
        "I () be seen!",
        "I ({{{cannot}}}) be seen!",
        .{ .cannot = null },
    );
}

test "Ampersand Null Interpolation" {
    try testCase(
        "I () be seen!",
        "I ({{&cannot}}) be seen!",
        .{ .cannot = null },
    );
}

test "Basic Context Miss Interpolation" {
    try testCase(
        "I () be seen!",
        "I ({{cannot}}) be seen!",
        .{},
    );
}

test "Triple Mustache Context Miss Interpolation" {
    try testCase(
        "I () be seen!",
        "I ({{{cannot}}}) be seen!",
        .{},
    );
}

test "Ampersand Context Miss Interpolation" {
    try testCase(
        "I () be seen!",
        "I ({{&cannot}}) be seen!",
        .{},
    );
}

test "Dotted Names - Basic Interpolation" {
    try testCase(
        "\"Joe\" == \"Joe\"",
        "\"{{person.name}}\" == \"{{#person}}{{name}}{{/person}}\"",
        .{ .person = .{ .name = "Joe" } },
    );
}

test "Dotted Names - Triple Mustache Interpolation" {
    try testCase(
        "\"Joe\" == \"Joe\"",
        "\"{{{person.name}}}\" == \"{{#person}}{{{name}}}{{/person}}\"",
        .{ .person = .{ .name = "Joe" } },
    );
}
test "Dotted Names - Ampersand Interpolation" {
    try testCase(
        "\"Joe\" == \"Joe\"",
        "\"{{&person.name}}\" == \"{{#person}}{{&name}}{{/person}}\"",
        .{ .person = .{ .name = "Joe" } },
    );
}

test "Dotted Names - Arbitrary Depth" {
    try testCase(
        "\"Phil\" == \"Phil\"",
        "\"{{a.b.c.d.e.name}}\" == \"Phil\"",
        .{ .a = .{ .b = .{ .c = .{ .d = .{ .e = .{ .name = "Phil" } } } } } },
    );
}

test "Dotted Names - Broken Chains" {
    try testCase(
        "\"\" == \"\"",
        "\"{{a.b.c}}\" == \"\"",
        .{ .a = .{} },
    );
}

test "Dotted Names - Broken Chain Resolution" {
    try testCase(
        "\"\" == \"\"",
        "\"{{a.b.c.name}}\" == \"\"",
        .{ .a = .{ .b = .{} }, .c = .{ .name = "Jim" } },
    );
}

test "Dotted Names - Initial Resolution" {
    try testCase(
        "\"Phil\" == \"Phil\"",
        "\"{{#a}}{{b.c.d.e.name}}{{/a}}\" == \"Phil\"",
        .{ .a = .{ .b = .{ .c = .{ .d = .{ .e = .{ .name = "Phil" } } } } }, .b = .{ .c = .{ .d = .{ .e = .{ .name = "Wrong" } } } } },
    );
}

test "Dotted Names - Context Precedence" {
    try testCase(
        "",
        "{{#a}}{{b.c}}{{/a}}",
        .{ .a = .{ .b = .{} }, .b = .{ .c = "ERROR" } },
    );
}

test "Dotted Names are never single keys" {
    try testCase(
        "",
        "{{a.b}}",
        .{ .@"a.b" = "c" },
    );
}

test "Dotted Names - No Masking" {
    try testCase(
        "d",
        "{{a.b}}",
        .{ .@"a.b" = "c", .a = .{ .b = "d" } },
    );
}

test "Implicit Iterators - Basic Interpolation" {
    try testCase(
        "Hello, world!\n",
        "Hello, {{.}}!\n",
        .{"world"},
    );
}

test "Implicit Iterators - HTML Escaping" {
    try testCase(
        "These characters should be HTML escaped: &amp; &quot; &lt; &gt;\n",
        "These characters should be HTML escaped: {{.}}\n",
        .{"& \" < >"},
    );
}

test "Implicit Iterators - Triple Mustache" {
    try testCase(
        "These characters should not be HTML escaped: & \" < >\n",
        "These characters should not be HTML escaped: {{{.}}}\n",
        .{"& \" < >"},
    );
}

test "Implicit Iterators - Ampersand" {
    try testCase(
        "These characters should not be HTML escaped: & \" < >\n",
        "These characters should not be HTML escaped: {{&.}}\n",
        .{"& \" < >"},
    );
}

test "Implicit Iterators - Basic Integer Interpolation" {
    try testCase(
        "\"85 miles an hour!\"",
        "\"{{.}} miles an hour!\"",
        .{85},
    );
}

test "Interpolation - Surrounding Whitespace" {
    try testCase(
        "| --- |",
        "| {{string}} |",
        .{ .string = "---" },
    );
}

test "Triple Mustache - Surrounding Whitespace" {
    try testCase(
        "| --- |",
        "| {{{string}}} |",
        .{ .string = "---" },
    );
}

test "Ampersand - Surrounding Whitespace" {
    try testCase(
        "| --- |",
        "| {{&string}} |",
        .{ .string = "---" },
    );
}

test "Interpolation - Standalone" {
    try testCase(
        "  ---\n",
        "  {{string}}\n",
        .{ .string = "---" },
    );
}

test "Triple Mustache - Standalone" {
    try testCase(
        "  ---\n",
        "  {{{string}}}\n",
        .{ .string = "---" },
    );
}

test "Ampersand - Standalone" {
    try testCase(
        "  ---\n",
        "  {{&string}}\n",
        .{ .string = "---" },
    );
}

test "Interpolation With Padding" {
    try testCase(
        "|---|",
        "|{{ string }}|",
        .{ .string = "---" },
    );
}

test "Triple Mustache With Padding" {
    try testCase(
        "|---|",
        "|{{{ string }}}|",
        .{ .string = "---" },
    );
}

test "Ampersand With Padding" {
    try testCase(
        "|---|",
        "|{{& string }}|",
        .{ .string = "---" },
    );
}

fn testCase(expected: []const u8, template: []const u8, data: anytype) !void {
    const actual = try renderSlice(testing.allocator, template, data);
    defer testing.allocator.free(actual);

    try testing.expectEqualStrings(expected, actual);
}

const std = @import("std");
const testing = std.testing;
const dirtstache = @import("dirtstache");
const Renderer = dirtstache.Renderer;
const renderSlice = Renderer.renderSlice;
