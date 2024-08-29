comptime {
    const std = @import("std");

    std.testing.refAllDecls(@import("interpolation.zig"));
}
