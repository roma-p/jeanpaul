const std = @import("std");
const gpa = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

const maths_vec = @import("maths_vec.zig");
const Vec3f32 = maths_vec.Vec3f32;

pub const BoundingBox = struct {
    x_min: f32,
    x_max: f32,
    y_min: f32,
    y_max: f32,
    z_min: f32,
    z_max: f32,

    const Self = @This();

    pub fn expand(self: Self, other: Self) Self {
        return Self{
            .x_min = @min(self.x_min, other.x_min),
            .x_max = @max(self.x_max, other.x_max),
            .y_min = @min(self.y_min, other.y_min),
            .y_max = @max(self.y_max, other.y_max),
            .z_min = @min(self.z_min, other.z_min),
            .z_max = @max(self.z_max, other.z_max),
        };
    }

    pub fn create_square_box_at_position(center: Vec3f32, size: f32) Self {
        const half_size = size / 2;
        return Self{
            .x_min = center.x - half_size,
            .x_max = center.x + half_size,
            .y_min = center.y - half_size,
            .y_max = center.y + half_size,
            .z_min = center.z - half_size,
            .z_max = center.z + half_size,
        };
    }

    pub fn create_null() Self {
        return Self{
            .x_min = 0,
            .x_max = 0,
            .y_min = 0,
            .y_max = 0,
            .z_min = 0,
            .z_max = 0,
        };
    }

    pub fn log_debug(self: Self) void {
        std.debug.print(
            "\nBBox -> x: {d}/{d}, y: {d}/{d}, z:{d}/{d}\n",
            .{
                self.x_min,
                self.x_max,
                self.y_min,
                self.y_max,
                self.z_min,
                self.z_max,
            },
        );
    }
};
