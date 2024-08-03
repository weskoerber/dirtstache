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
                        const str = try formatValue(allocator, value);
                        defer allocator.free(str);
                        try dest.appendSlice(str);
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

fn formatValue(allocator: Allocator, value: anytype) ![]const u8 {
    return switch (@typeInfo(@TypeOf(value))) {
        .Bool => try fmt.allocPrint(allocator, "{s}", .{if (value) "true" else "false"}),
        .Int, .ComptimeInt => try fmt.allocPrint(allocator, "{d}", .{value}),
        .Array => |a| if (a.child != u8) @panic("Pointer to " ++ @typeName(a.child) ++ " not allowed") else try fmt.allocPrint(allocator, "{s}", .{value}),
        .Pointer => |p| if (@typeInfo(p.child) != .Array) @panic("Pointer to " ++ @typeName(p.child) ++ " not allowed") else try fmt.allocPrint(allocator, "{s}", .{value}),
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
