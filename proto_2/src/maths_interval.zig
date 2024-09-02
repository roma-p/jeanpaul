const std = @import("std");

pub const Interval = struct {
    min: f32,
    max: f32,

    const Self = @This();

    pub fn interval_union(self: Self, other: Self) Self {
        return Self{
            .min = @max(self.min, other.min),
            .max = @max(self.max, other.max),
        };
    }
};
