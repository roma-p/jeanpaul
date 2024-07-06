const std = @import("std");
const allocator = std.heap.page_allocator;
const maths_vec = @import("maths_vec.zig");
const Vec3f32 = maths_vec.Vec3f32;

pub const TMatrix = struct {
    m: [4][4]f32 = TRANSFORM_MATRIX_IDENTITY,

    const Self = @This();

    const TRANSFORM_MATRIX_IDENTITY = [4][4]f32{
        [_]f32{ 1, 0, 0, 0 },
        [_]f32{ 0, 1, 0, 0 },
        [_]f32{ 0, 0, 1, 0 },
        [_]f32{ 0, 0, 0, 1 },
    };

    pub fn set_position(
        self: Self,
        position: Vec3f32,
    ) !void {
        self.m[0][3] = position.x;
        self.m[1][3] = position.y;
        self.m[2][3] = position.z;
    }

    pub fn get_position(self: Self) Vec3f32 {
        return Vec3f32{
            .x = self.m[0][3],
            .y = self.m[1][3],
            .z = self.m[2][3],
        };
    }

    pub fn set_tmatrix(self: Self, matrix: [4][4]f32) void {
        for (matrix, 0..) |_, x| {
            for (matrix[x], 0..) |value, y| {
                self.m[x][y] = value;
            }
        }
    }

    pub fn translate(self: Self, position: Vec3f32) void {
        self.m[0][3] += position.x;
        self.m[1][3] += position.y;
        self.m[2][3] += position.z;
    }

    pub fn multiply_with_vec3(self: Self, vector: Vec3f32) Vec3f32 {
        //FIXME: is thois correct x or y inversed or what?
        return Vec3f32{
            .x = self.m[0][0] * vector.x + self.m[0][1] * vector.y + self.m[0][2] * vector.z,
            .y = self.m[1][0] * vector.x + self.m[1][1] * vector.y + self.m[1][2] * vector.z,
            .z = self.m[2][0] * vector.x + self.m[2][1] * vector.y + self.m[2][2] * vector.z,
        };
    }

    pub fn log_debug(self: Self) void {
        std.debug.print("\n{} {} {} {}", .{ self.m[0][0], self.m[0][1], self.m[0][2], self.m[0][3] });
        std.debug.print("\n{} {} {} {}", .{ self.m[1][0], self.m[1][1], self.m[1][2], self.m[1][3] });
        std.debug.print("\n{} {} {} {}", .{ self.m[2][0], self.m[2][1], self.m[2][2], self.m[2][3] });
        std.debug.print("\n{} {} {} {}\n", .{ self.m[3][0], self.m[3][1], self.m[3][2], self.m[3][3] });
    }
};
