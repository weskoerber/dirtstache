start_pos: usize,
end_pos: usize,
type: TokenType,

pub const L_BRACE = '{';
pub const R_BRACE = '}';
pub const EXCL = '!';
pub const DOT = '.';
pub const AMP = '&';
pub const NUM = '#';
pub const CARAT = '^';
pub const F_SLASH = '/';
pub const GT = '>';
pub const LT = '<';
pub const QUOT = '"';

pub const TokenType = enum {
    none,

    /// {{var}}
    variable,

    // {{& var}}
    noescape,

    // {{{var}}}
    noescape_3,

    // {{! comment}}
    comment,

    // {{.}}
    implicit_iter,

    // {{# section}}
    section_open,

    // {{^ section}}
    inverted_open,

    // {{/ section}}
    section_close,

    // {{> partial}}
    partial,
};

pub fn getName(token: Token, s: []const u8) []const u8 {
    const name = switch (token.type) {
        .variable => s[token.start_pos + 2 .. token.end_pos - 1],
        .noescape,
        .section_open,
        .inverted_open,
        .section_close,
        .partial,
        => s[token.start_pos + 3 .. token.end_pos - 1],
        .noescape_3 => s[token.start_pos + 3 .. token.end_pos - 2],
        .implicit_iter => ".",
        .none, .comment => "",
    };

    return std.mem.trim(u8, name, " ");
}

const std = @import("std");
const testing = std.testing;
const Token = @This();

test "token name - comment" {
    const str = "{{!comment}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .comment };

    try testing.expectEqualStrings("", tok.getName(str));
}

test "token name - variable" {
    const str = "{{my_var}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .variable };

    try testing.expectEqualStrings("my_var", tok.getName(str));
}

test "token name - noescape" {
    const str = "{{& raw_data}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .noescape };

    try testing.expectEqualStrings("raw_data", tok.getName(str));
}

test "token name - noescape_3" {
    const str = "{{{ raw_data}}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .noescape_3 };

    try testing.expectEqualStrings("raw_data", tok.getName(str));
}

test "token name - implicit_iter" {
    const str = "{{.}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .implicit_iter };

    try testing.expectEqualStrings(".", tok.getName(str));
}

test "token name - section_open" {
    const str = "{{# my_section}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .section_open };

    try testing.expectEqualStrings("my_section", tok.getName(str));
}

test "token name - inverted_open" {
    const str = "{{^ my_inverted}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .inverted_open };

    try testing.expectEqualStrings("my_inverted", tok.getName(str));
}

test "token name - section_close" {
    const str = "{{/ my_section}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .section_close };

    try testing.expectEqualStrings("my_section", tok.getName(str));
}

test "token name - partial" {
    const str = "{{/ my_partial}}";
    const tok = Token{ .start_pos = 0, .end_pos = str.len - 1, .type = .partial };

    try testing.expectEqualStrings("my_partial", tok.getName(str));
}
