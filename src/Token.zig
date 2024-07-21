start_pos: usize,
end_pos: usize,
type: TokenType,

pub const L_BRACE = '{';
pub const R_BRACE = '}';
pub const EXCL = '!';
pub const DOT = '.';
pub const AMP = '&';

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
