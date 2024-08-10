const std = @import("std");
const gpa = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

const constants = @import("constants.zig");
const maths = @import("maths.zig");

pub fn Vec2(comptime T: type) type {
    return struct { x: T = 0, y: T = 0 };
}

pub const Vec2u16 = Vec2(u16);

pub const Vec3f32 = struct {
    x: f32 = undefined,
    y: f32 = undefined,
    z: f32 = undefined,

    const Self = @This();

    pub fn create_origin() Self {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn create_x() Self {
        return .{ .x = 1, .y = 0, .z = 0 };
    }

    pub fn create_y() Self {
        return .{ .x = 0, .y = 1, .z = 0 };
    }

    pub fn create_z() Self {
        return .{ .x = 0, .y = 0, .z = 1 };
    }

    pub fn create_x_neg() Self {
        return Self.create_x().product(-1);
    }

    pub fn create_y_neg() Self {
        return Self.create_y().product(-1);
    }

    pub fn create_z_neg() Self {
        return Self.create_z().product(-1);
    }

    pub fn check_is_equal(self: Self, vec: Vec3f32) bool {
        return (self.x == vec.x and self.y == vec.y and self.z == vec.z);
    }

    pub fn product(self: Self, x: f32) Self {
        return Self{
            .x = x * self.x,
            .y = x * self.y,
            .z = x * self.z,
        };
    }

    pub fn product_dot(self: Self, vec: Self) f32 {
        return self.x * vec.x + self.y * vec.y + self.z * vec.z;
    }

    pub fn sum_vector(self: Self, vec: Self) Self {
        return Self{
            .x = self.x + vec.x,
            .y = self.y + vec.y,
            .z = self.z + vec.z,
        };
    }

    pub fn substract_vector(self: Self, vec: Self) Self {
        return Self{
            .x = self.x - vec.x,
            .y = self.y - vec.y,
            .z = self.z - vec.z,
        };
    }

    pub fn normalize(self: Self) Self {
        const magnitude = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        return Self{
            .x = self.x / magnitude,
            .y = self.y / magnitude,
            .z = self.z / magnitude,
        };
    }

    pub fn almsot_null(self: Self) bool {
        return (@abs(self.x) < constants.EPSILON and @abs(self.y) < constants.EPSILON and @abs(self.z) < constants.EPSILON);
    }

    pub fn compute_length(self: Self) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn compute_length_squared(self: Self) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn log_debug(self: Self) void {
        std.debug.print(
            "\nVec -> x:{d}, y:{d}, z:{d}\n",
            .{ self.x, self.y, self.z },
        );
    }
};

// -- TESTS ------------------------------------------------------------------

test "u_create_vec" {
    const vec_1 = Vec3f32.create_x();
    try std.testing.expectEqual(1, vec_1.x);
    try std.testing.expectEqual(0, vec_1.y);
    try std.testing.expectEqual(0, vec_1.z);

    const vec_2 = Vec3f32.create_y();
    try std.testing.expectEqual(0, vec_2.x);
    try std.testing.expectEqual(1, vec_2.y);
    try std.testing.expectEqual(0, vec_2.z);

    const vec_3 = Vec3f32.create_z();
    try std.testing.expectEqual(0, vec_3.x);
    try std.testing.expectEqual(0, vec_3.y);
    try std.testing.expectEqual(1, vec_3.z);

    const vec_4 = Vec3f32.create_x_neg();
    try std.testing.expectEqual(-1, vec_4.x);
    try std.testing.expectEqual(0, vec_4.y);
    try std.testing.expectEqual(0, vec_4.z);

    const vec_5 = Vec3f32.create_y_neg();
    try std.testing.expectEqual(0, vec_5.x);
    try std.testing.expectEqual(-1, vec_5.y);
    try std.testing.expectEqual(0, vec_5.z);

    const vec_6 = Vec3f32.create_z_neg();
    try std.testing.expectEqual(0, vec_6.x);
    try std.testing.expectEqual(0, vec_6.y);
    try std.testing.expectEqual(-1, vec_6.z);
}

test "u_check_is_equal" {
    const vec_1 = Vec3f32{ .x = 1, .y = 2, .z = 3 };
    const vec_2 = Vec3f32{ .x = 1, .y = 2, .z = 3 };
    const vec_3 = Vec3f32{ .x = 2, .y = 2, .z = 3 };

    try std.testing.expectEqual(true, vec_1.check_is_equal(vec_2));
    try std.testing.expectEqual(false, vec_1.check_is_equal(vec_3));
}

test "u_product" {
    const vec_1 = Vec3f32{ .x = 1, .y = 2, .z = 3 };
    const vec_2 = vec_1.product(3);
    try std.testing.expectEqual(3, vec_2.x);
    try std.testing.expectEqual(6, vec_2.y);
    try std.testing.expectEqual(9, vec_2.z);
}

test "u_product_dot" {
    const vec_1 = Vec3f32{ .x = 1, .y = 2, .z = 3 };
    const vec_2 = Vec3f32{ .x = 2, .y = 2, .z = 2 };
    const out = vec_1.product_dot(vec_2);
    try std.testing.expectEqual(12, out);
}

test "u_sum_vector" {
    const vec_1 = Vec3f32{ .x = 1, .y = 2, .z = 3 };
    const vec_2 = Vec3f32{ .x = 1, .y = 2, .z = 3 };
    const vec_3 = vec_1.sum_vector(vec_2);

    try std.testing.expectEqual(2, vec_3.x);
    try std.testing.expectEqual(4, vec_3.y);
    try std.testing.expectEqual(6, vec_3.z);
}

test "u_substract_vector" {
    const vec_1 = Vec3f32{ .x = 1, .y = 2, .z = 3 };
    const vec_2 = Vec3f32{ .x = 3, .y = 1, .z = 3 };
    const vec_3 = vec_1.substract_vector(vec_2);

    try std.testing.expectEqual(-2, vec_3.x);
    try std.testing.expectEqual(1, vec_3.y);
    try std.testing.expectEqual(0, vec_3.z);
}

test "u_compute_length" {
    const vec_1 = Vec3f32{ .x = 1, .y = 1, .z = 3 };
    const length: f32 = vec_1.compute_length();
    try std.testing.expectEqual(true, maths.check_almost_equal(3.3166249, length));
}

test "u_normalize" {
    const vec_1 = Vec3f32{ .x = 1, .y = 1, .z = 3 };
    const vec_2 = vec_1.normalize();
    const length: f32 = vec_2.compute_length();
    try std.testing.expectEqual(true, maths.check_almost_equal(1, length));
}

test "u_log_debug" {
    const vec_1 = Vec3f32{ .x = 1, .y = 1, .z = 3 };
    vec_1.log_debug();
}
