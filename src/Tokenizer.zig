pub fn parseFromSlice(allocator: Allocator, s: []const u8) ![]const Token {
    var tokens = ArrayList(Token).init(allocator);
    var index: usize = 0;
    var state: State = .raw;
    var prev_char: u8 = 0;
    var curr_char: u8 = 0;
    var curr_token: Token = .{ .start_pos = 0, .end_pos = 0, .type = .none };

    while (true) : (index += 1) {
        if (index >= s.len) {
            break;
        }

        curr_char = s[index];

        switch (state) {
            .raw, .complete_tag => {
                switch (curr_char) {
                    Token.L_BRACE => state = .open_1,
                    else => {},
                }
            },
            .open_1 => {
                switch (curr_char) {
                    Token.L_BRACE => {
                        state = .open_2;
                    },
                    Token.R_BRACE => {
                        // ex: {{}
                        return error.InvalidToken;
                    },
                    else => state = .raw,
                }
            },
            .open_2 => {
                switch (curr_char) {
                    Token.L_BRACE => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .noescape_variable;
                        state = .within_tag;
                    },
                    Token.COMMENT => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .comment;
                        state = .within_tag;
                    },
                    Token.R_BRACE => {
                        // ex: {{{}
                        return error.InvalidToken;
                    },
                    else => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .variable;
                        state = .within_tag;
                    },
                }
            },
            .within_tag => {
                switch (curr_char) {
                    Token.R_BRACE => state = .close_1,
                    else => {},
                }
            },
            .close_1 => {
                switch (curr_char) {
                    Token.R_BRACE => {
                        switch (curr_token.type) {
                            .variable, .comment => {
                                state = .complete_tag;
                                curr_token.end_pos = index;
                                try tokens.append(curr_token);
                            },
                            .noescape_variable => state = .close_2,
                            .none => return error.InvalidToken,
                        }
                    },
                    else => state = .within_tag,
                }
            },
            .close_2 => {
                switch (curr_char) {
                    Token.R_BRACE => {
                        state = .complete_tag;
                        curr_token.end_pos = index;
                        try tokens.append(curr_token);
                    },
                    else => return error.InvalidToken,
                }
            },
        }

        prev_char = curr_char;
    }

    return tokens.toOwnedSlice();
}

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Token = @import("Token.zig");
const State = enum {
    raw,
    open_1,
    open_2,
    within_tag,
    close_1,
    close_2,
    complete_tag,
};

test "sanity" {
    const str = "";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{}, toks);
}

test "variables - single with no other characters" {
    const str = "{{name}}";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 0, .end_pos = str.len - 1, .type = .variable },
    }, toks);
}

test "variables - single with other characters" {
    const str = "Hello, {{name}}";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 7, .end_pos = str.len - 1, .type = .variable },
    }, toks);

    try testing.expectEqualStrings("{{name}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
}

test "variables - multiple with no other characters" {
    const str = "Name: {{last_name}}, {{first_name}}.";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 6, .end_pos = 18, .type = .variable },
        .{ .start_pos = 21, .end_pos = 34, .type = .variable },
    }, toks);

    try testing.expectEqualStrings("{{last_name}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
    try testing.expectEqualStrings("{{first_name}}", str[toks[1].start_pos .. toks[1].end_pos + 1]);
}

test "noescape - no escape" {
    const str = "Time: {{{html_data}}} seconds.";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 6, .end_pos = 20, .type = .noescape_variable },
    }, toks);

    try testing.expectEqualStrings("{{{html_data}}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
}

test "comment - comment" {
    const str = "Time: {{! this is a comment}}{{secs}} seconds.";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 6, .end_pos = 28, .type = .comment },
        .{ .start_pos = 29, .end_pos = 36, .type = .variable },
    }, toks);

    try testing.expectEqualStrings("{{! this is a comment}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
    try testing.expectEqualStrings("{{secs}}", str[toks[1].start_pos .. toks[1].end_pos + 1]);
}