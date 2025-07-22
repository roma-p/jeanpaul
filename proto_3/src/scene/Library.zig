const std = @import("std");

pub const Library = @This();

materials: std.MultiArrayList(
    struct{
        name: []const u8,
        material: u32,
    }
),

shape: std.MultiArrayList(
    struct{
        name: []const u8,
        shape: u32,
    }
),
