const std = @import("std");
const allocator = std.heap.page_allocator;

// ==== VECTORS ==============================================================

pub const Vec2u16 = struct {
    x: u16 = undefined,
    y: u16 = undefined,
};

pub const Vec2f32 = struct {
    x: f32 = undefined,
    y: f32 = undefined,
};

pub const Vec3f32 = struct {
    x: f32 = undefined,
    y: f32 = undefined,
    z: f32 = undefined,

    // TODO: rename scale anrold: "atVectorAPI"
    pub fn product_scalar(self: *const Vec3f32, x: f32) Vec3f32 {
        return Vec3f32{
            .x = x * self.x,
            .y = x * self.y,
            .z = x * self.z,
        };
    }

    pub fn substract_vector(self: *const Vec3f32, vec: *const Vec3f32) Vec3f32 {
        return Vec3f32{
            .x = self.x - vec.x,
            .y = self.y - vec.y,
            .z = self.z - vec.z,
        };
    }

    pub fn sum_vector(self: *const Vec3f32, vec: *const Vec3f32) Vec3f32 {
        return Vec3f32{
            .x = self.x + vec.x,
            .y = self.y + vec.y,
            .z = self.z + vec.z,
        };
    }

    pub fn product_dot(self: *const Vec3f32, vec: *const Vec3f32) f32 {
        return self.x * vec.x + self.y * vec.y + self.z * vec.z;
    }

    pub fn normalize(self: *const Vec3f32) Vec3f32 {
        const magnitude = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        return Vec3f32{
            .x = self.x / magnitude,
            .y = self.y / magnitude,
            .z = self.z / magnitude,
        };
    }
};

// ==== 2D BOUNDING RECTANGLE ================================================

pub const BoudingRectangleu16 = struct {
    x_min: u16 = undefined,
    x_max: u16 = undefined,
    y_min: u16 = undefined,
    y_max: u16 = undefined,
};

// ==== TRANSFORMATION MATRIX (4x4) ==========================================

pub const TMatrixf32 = struct {
    m: [4][4]f32 = TRANSFORM_MATRIX_IDENTITY,

    const Self = @This();

    pub fn new() !*Self {
        var matrix = try allocator.create(Self);
        matrix.* = Self{};
        return matrix;
    }

    pub fn delete(self: *Self) void {
        allocator.destroy(self);
    }

    pub fn set_position(
        self: *TMatrixf32,
        position: *const Vec3f32,
    ) !void {
        self.m[0][3] = position.x;
        self.m[1][3] = position.y;
        self.m[2][3] = position.z;
    }

    pub fn get_position(self: *const TMatrixf32) Vec3f32 {
        return Vec3f32{
            .x = self.m[0][3],
            .y = self.m[1][3],
            .z = self.m[2][3],
        };
    }

    pub fn set_tmatrix(self: *const TMatrixf32, matrix: *[4][4]f32) void {
        for (matrix, 0..) |_, x| {
            for (matrix[x], 0..) |value, y| {
                self.m[x][y] = value;
            }
        }
    }

    pub fn translate(
        self: *const TMatrixf32,
        position: *Vec3f32,
    ) void {
        self.m[0][3] += position.x;
        self.m[1][3] += position.y;
        self.m[2][3] += position.z;
    }
};

const TRANSFORM_MATRIX_IDENTITY = [_][4]f32{
    [_]f32{ 1, 0, 0, 0 },
    [_]f32{ 0, 1, 0, 0 },
    [_]f32{ 0, 0, 1, 0 },
    [_]f32{ 0, 0, 0, 1 },
};

pub const JP_EPSILON = 0.000001;

// ==== HELPERS ==============================================================

pub fn cast_u16_to_f32(input: u16) f32 {
    // didn't find how to do this directly without casting as int first...
    // used mainly to go from screen space (2d u16 array) to 3d space (3d f32 array)
    const tmp: i32 = input;
    const ret: f32 = @floatFromInt(tmp);
    return ret;
}

pub fn absolute(number: f32) f32 {
    // didn't succeeded to make "@abs" builtin work so reimplementing it...
    if (number >= 0) {
        return number;
    } else {
        return number + 2 * number;
    }
}
