const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

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

pub const AovStandard = enum {
    Beauty,
    Alpha,
    Depth,
    Normal,
};

pub fn add_aov_standard(self: *ControllerAov, aov_standard: AovStandard) !void {
    for (self.array_aov_standard.items) |i| {
        if (i == aov_standard) return;
    }
    try self.array_aov_standard.append(aov_standard);
}
