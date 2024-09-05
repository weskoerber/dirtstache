pub fn renderSlice(allocator: Allocator, s: []const u8, comptime data: anytype) ![]const u8 {
    var dest = ArrayList(u8).init(allocator);
    errdefer dest.deinit();

    const tokens = try Tokenizer.parseFromSlice(allocator, s);
    defer allocator.free(tokens);
    var prev_pos: usize = 0;

    for (tokens) |token| {
        try dest.appendSlice(s[prev_pos..token.start_pos]);

        const data_type = @TypeOf(data);
        const data_typeinfo = @typeInfo(data_type);

        switch (token.type) {
            .noescape, .noescape_3, .variable => {
                inline for (data_typeinfo.@"struct".fields) |field| {
                    if (std.mem.eql(u8, token.getName(s), field.name)) {
                        const value = @field(data, field.name);
                        if (try formatValue(allocator, value, token.type == .variable)) |str| {
                            defer allocator.free(str);
                            try dest.appendSlice(str);
                        }
                    }
                }
            },
            .comment => {},
            else => {
                std.debug.panic("TODO: Token '{s}' is not yet implemented", .{@tagName(token.type)});
            },
        }

        prev_pos = token.end_pos + 1;
    }

    if (prev_pos < s.len) {
        try dest.appendSlice(s[prev_pos..s.len]);
    }

    return try dest.toOwnedSlice();
}

fn formatValue(allocator: Allocator, value: anytype, escape: bool) !?[]const u8 {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => try fmt.allocPrint(allocator, "{s}", .{if (value) "true" else "false"}),
        .int, .comptime_int => try fmt.allocPrint(allocator, "{d}", .{value}),
        .float, .comptime_float => try fmt.allocPrint(allocator, "{d}", .{value}),
        .array => |a| blk: {
            if (a.child != u8) @panic("Array of " ++ @typeName(a.child) ++ " not allowed");

            if (escape) {
                var buf = try std.ArrayList(u8).initCapacity(allocator, value.len);
                for (value) |c| {
                    switch (c) {
                        Token.AMP => try buf.appendSlice("&amp;"),
                        Token.QUOT => try buf.appendSlice("&quot;"),
                        Token.LT => try buf.appendSlice("&lt;"),
                        Token.GT => try buf.appendSlice("&gt;"),
                        else => try buf.append(c),
                    }
                }

                break :blk try buf.toOwnedSlice();
            } else {
                break :blk try fmt.allocPrint(allocator, "{s}", .{value});
            }
        },
        .pointer => |p| blk: {
            if (@typeInfo(p.child) != .array) @panic("Pointer to " ++ @typeName(p.child) ++ " not allowed");
            break :blk try formatValue(allocator, value.*, escape);
        },
        .null => null,
        else => @panic("TODO: Type '" ++ @typeName(@TypeOf(value)) ++ " not yet implemented"),
    };
}

const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Token = @import("Token.zig");
const Tokenizer = @import("Tokenizer.zig");
