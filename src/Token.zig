start_pos: usize,
end_pos: usize,
type: TokenType,

pub const L_BRACE = '{';
pub const R_BRACE = '}';
pub const COMMENT = '!';
pub const DOT = '.';
pub const RAW = '&';

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
};
