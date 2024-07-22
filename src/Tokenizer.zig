pub fn parseFromSlice(allocator: Allocator, s: []const u8) ![]const Token {
    var tokens = ArrayList(Token).init(allocator);
    var index: usize = 0;
    var state: State = .raw;
    var curr_char: u8 = 0;
    var curr_token: Token = .{ .start_pos = 0, .end_pos = 0, .type = .none };

    errdefer tokens.deinit();

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
                        state = .open_3;
                    },
                    Token.EXCL => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .comment;
                        state = .within_tag;
                    },
                    Token.DOT => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .implicit_iter;
                        state = .within_tag;
                    },
                    Token.AMP => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .noescape;
                        state = .within_tag;
                    },
                    Token.NUM => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .section_open;
                        state = .within_tag;
                    },
                    Token.CARAT => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .inverted_open;
                        state = .within_tag;
                    },
                    Token.F_SLASH => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .section_close;
                        state = .within_tag;
                    },
                    Token.GT => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .partial;
                        state = .within_tag;
                    },
                    Token.R_BRACE => return error.InvalidToken,
                    else => {
                        curr_token.start_pos = index - 2;
                        curr_token.type = .variable;
                        state = .within_tag;
                    },
                }
            },
            .open_3 => {
                switch (curr_char) {
                    Token.L_BRACE,
                    Token.R_BRACE,
                    Token.EXCL,
                    Token.AMP,
                    Token.F_SLASH,
                    => return error.InvalidToken,
                    else => {
                        curr_token.start_pos = index - 3;
                        curr_token.type = .noescape_3;
                        state = .within_tag;
                    },
                }
            },
            .within_tag => {
                switch (curr_char) {
                    Token.R_BRACE => state = .close_1,
                    else => {
                        switch (curr_token.type) {
                            .implicit_iter => {
                                if (curr_char != Token.R_BRACE) {
                                    return error.InvalidToken;
                                }
                            },
                            else => {},
                        }
                    },
                }
            },
            .close_1 => {
                switch (curr_char) {
                    Token.R_BRACE => {
                        switch (curr_token.type) {
                            .variable,
                            .comment,
                            .implicit_iter,
                            .noescape,
                            .section_open,
                            .inverted_open,
                            .section_close,
                            .partial,
                            => {
                                state = .complete_tag;
                                curr_token.end_pos = index;
                                try tokens.append(curr_token);
                            },
                            .noescape_3 => state = .close_2,
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
    open_3,
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

test "variables - invalid closing tag" {
    const str = "Names: {{}}";
    const err = parseFromSlice(testing.allocator, str);
    try testing.expectError(error.InvalidToken, err);
}

test "noescape3 - no escape" {
    const str = "Time: {{{html_data}}} seconds.";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 6, .end_pos = 20, .type = .noescape_3 },
    }, toks);

    try testing.expectEqualStrings("{{{html_data}}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
}

test "noescape3 - invalid closing tag" {
    const str = "Names: {{{}}}";
    const err = parseFromSlice(testing.allocator, str);
    try testing.expectError(error.InvalidToken, err);
}

test "noescape - no escape" {
    const str = "Time: {{& html_data}} seconds.";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 6, .end_pos = 20, .type = .noescape },
    }, toks);

    try testing.expectEqualStrings("{{& html_data}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
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

test "iterator - implicit" {
    const str = "Names: {{.}}";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 7, .end_pos = 11, .type = .implicit_iter },
    }, toks);

    try testing.expectEqualStrings("{{.}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
}

test "iterator - invalid implicit" {
    const str = "Names: {{.names}}";
    const err = parseFromSlice(testing.allocator, str);
    try testing.expectError(error.InvalidToken, err);
}

test "section - section" {
    const str = "{{#person}}\n    Never shown!\n{{/person}}";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 0, .end_pos = 10, .type = .section_open },
        .{ .start_pos = 29, .end_pos = 39, .type = .section_close },
    }, toks);

    try testing.expectEqualStrings("{{#person}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
    try testing.expectEqualStrings("{{/person}}", str[toks[1].start_pos .. toks[1].end_pos + 1]);
}

test "section - inverted" {
    const str = "{{^person}}\n    Never shown!\n{{/person}}";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 0, .end_pos = 10, .type = .inverted_open },
        .{ .start_pos = 29, .end_pos = 39, .type = .section_close },
    }, toks);

    try testing.expectEqualStrings("{{^person}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
    try testing.expectEqualStrings("{{/person}}", str[toks[1].start_pos .. toks[1].end_pos + 1]);
}

test "partial - partial" {
    const str = "Themes: {{> some_partial}}";
    const toks = try parseFromSlice(testing.allocator, str);
    defer testing.allocator.free(toks);
    try testing.expectEqualSlices(Token, &.{
        .{ .start_pos = 8, .end_pos = 25, .type = .partial },
    }, toks);

    try testing.expectEqualStrings("{{> some_partial}}", str[toks[0].start_pos .. toks[0].end_pos + 1]);
}
