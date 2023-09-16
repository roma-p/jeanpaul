const std = @import("std");
const stdout = std.io.getStdOut().writer();

pub fn helloworld() !void {
    try stdout.print("helloworld", .{});
}
