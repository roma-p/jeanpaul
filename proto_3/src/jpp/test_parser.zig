const std = @import("std");
const testing = std.testing;

const Ast = @import("Ast.zig");

test "most basic" {
    const example =
        \\
        \\Scene{
        \\  name="default",
        \\  from=("env", "cam"),
        \\  library=("default",),
        \\}
        \\\
    ;
    const gpa = testing.allocator;
    var ast = try Ast.parse(gpa, example);
    defer ast.deinit(gpa);
}
