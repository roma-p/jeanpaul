const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const definitions = @import("definitions.zig");
const AovStandard = definitions.AovStandardEnum;

pub const ControllerAov = @This();

array_aov_standard: std.ArrayList(AovStandard),

pub fn init() ControllerAov {
    return .{
        .array_aov_standard = std.ArrayList(AovStandard).init(gpa),
    };
}

pub fn deinit(self: *ControllerAov) void {
    self.array_aov_standard.deinit();
}

pub fn add_aov_standard(self: *ControllerAov, aov_standard: AovStandard) !void {
    for (self.array_aov_standard.items) |i| {
        if (i == aov_standard) return;
    }
    try self.array_aov_standard.append(aov_standard);
}
