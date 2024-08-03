const std = @import("std");
const allocator = std.heap.page_allocator;
const maths_vec = @import("maths_vec.zig");
const Vec3f32 = maths_vec.Vec3f32;

pub const TMatrix = struct {
    m: [4][4]f32,

    const Self = @This();

    const TRANSFORM_MATRIX_IDENTITY = [4][4]f32{
        [_]f32{ 1, 0, 0, 0 },
        [_]f32{ 0, 1, 0, 0 },
        [_]f32{ 0, 0, 1, 0 },
        [_]f32{ 0, 0, 0, 1 },
    };

    pub fn create_identity() Self {
        return .{ .m = TRANSFORM_MATRIX_IDENTITY };
    }

    pub fn create_at_position(position: Vec3f32) Self {
        var ret = Self.create_identity();
        ret.set_position(position);
        return ret;
    }

    pub fn set_position(
        self: *Self,
        position: Vec3f32,
    ) void {
        self.*.m[0][3] = position.x;
        self.*.m[1][3] = position.y;
        self.*.m[2][3] = position.z;
    }

    pub fn get_position(self: Self) Vec3f32 {
        return Vec3f32{
            .x = self.m[0][3],
            .y = self.m[1][3],
            .z = self.m[2][3],
        };
    }

    pub fn set_tmatrix(self: *Self, matrix: [4][4]f32) void {
        for (matrix, 0..) |_, x| {
            for (matrix[x], 0..) |value, y| {
                self.*.m[x][y] = value;
            }
        }
    }

    pub fn translate(self: *Self, position: Vec3f32) void {
        self.*.m[0][3] += position.x;
        self.*.m[1][3] += position.y;
        self.*.m[2][3] += position.z;
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
        std.debug.print("\n{d} {d} {d} {d}", .{ self.m[0][0], self.m[0][1], self.m[0][2], self.m[0][3] });
        std.debug.print("\n{d} {d} {d} {d}", .{ self.m[1][0], self.m[1][1], self.m[1][2], self.m[1][3] });
        std.debug.print("\n{d} {d} {d} {d}", .{ self.m[2][0], self.m[2][1], self.m[2][2], self.m[2][3] });
        std.debug.print("\n{d} {d} {d} {d}\n", .{ self.m[3][0], self.m[3][1], self.m[3][2], self.m[3][3] });
    }
};

test "u_set_position" {
    var tmat = TMatrix.create_identity();
    tmat.set_position(Vec3f32.create_x());
    try std.testing.expectEqual(1, tmat.m[0][3]);
    try std.testing.expectEqual(0, tmat.m[1][3]);
    try std.testing.expectEqual(0, tmat.m[2][3]);
}

test "u_get_position" {
    var tmat = TMatrix.create_identity();
    tmat.m[0][3] = 1;
    tmat.m[1][3] = 2;
    tmat.m[2][3] = 3;
    const position = tmat.get_position();
    try std.testing.expectEqual(1, position.x);
    try std.testing.expectEqual(2, position.y);
    try std.testing.expectEqual(3, position.z);
}

test "u_set_tmatrix" {
    const NEW_MATRIX = [4][4]f32{
        [_]f32{ 1, 2, 3, 4 },
        [_]f32{ 5, 6, 7, 8 },
        [_]f32{ 9, 10, 11, 12 },
        [_]f32{ 13, 14, 15, 16 },
    };

    var tmat = TMatrix.create_identity();
    tmat.set_tmatrix(NEW_MATRIX);
    try std.testing.expectEqual(1, tmat.m[0][0]);
    try std.testing.expectEqual(2, tmat.m[0][1]);
    try std.testing.expectEqual(3, tmat.m[0][2]);
    try std.testing.expectEqual(4, tmat.m[0][3]);
    try std.testing.expectEqual(5, tmat.m[1][0]);
    try std.testing.expectEqual(6, tmat.m[1][1]);
    try std.testing.expectEqual(7, tmat.m[1][2]);
    try std.testing.expectEqual(8, tmat.m[1][3]);
    try std.testing.expectEqual(9, tmat.m[2][0]);
    try std.testing.expectEqual(10, tmat.m[2][1]);
    try std.testing.expectEqual(11, tmat.m[2][2]);
    try std.testing.expectEqual(12, tmat.m[2][3]);
    try std.testing.expectEqual(13, tmat.m[3][0]);
    try std.testing.expectEqual(14, tmat.m[3][1]);
    try std.testing.expectEqual(15, tmat.m[3][2]);
    try std.testing.expectEqual(16, tmat.m[3][3]);
}

test "u_translate" {
    var tmat = TMatrix.create_identity();
    tmat.m[0][3] = 1;
    tmat.m[1][3] = 2;
    tmat.m[2][3] = 3;
    const position = Vec3f32{ .x = 1, .y = 1, .z = 1 };
    tmat.translate(position);
    try std.testing.expectEqual(2, tmat.m[0][3]);
    try std.testing.expectEqual(3, tmat.m[1][3]);
    try std.testing.expectEqual(4, tmat.m[2][3]);
}

test "u_multiply_with_vec3" {
    var tmat = TMatrix.create_identity();
    tmat.m[0][3] = 1;
    tmat.m[1][3] = 2;
    tmat.m[2][3] = 3;
    const position = Vec3f32{ .x = 2, .y = 2, .z = 2 };
    const out = tmat.multiply_with_vec3(position);
    try std.testing.expectEqual(2, out.x);
    try std.testing.expectEqual(2, out.y);
    try std.testing.expectEqual(2, out.z);
}

test "u_log_debug" {
    var tmat = TMatrix.create_identity();
    tmat.log_debug();
}

test "u_create_at_position" {
    const t = TMatrix.create_at_position(Vec3f32{ .x = 1, .y = 2, .z = 3 });
    try std.testing.expectEqual(1, t.m[0][3]);
    try std.testing.expectEqual(2, t.m[1][3]);
    try std.testing.expectEqual(3, t.m[2][3]);
}
