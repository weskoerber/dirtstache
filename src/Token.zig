start_pos: usize,
end_pos: usize,
type: TokenType,

pub const L_BRACE = '{';
pub const R_BRACE = '}';
pub const COMMENT = '!';

pub const TokenType = enum {
    none,
    variable,
    noescape_variable,
    comment,
};
