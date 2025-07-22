const std = @import("std");

pub const Scene = @This();

world: std.MultiArrayList(
    struct{
        name: []const u8,
        src_idx: u32,
        tmat: u32,
    }
),

camera_idx: std.ArrayList(u32),
shape_idx: std.ArrayList(u32),
