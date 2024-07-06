const std = @import("std");
const gpa = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

pub const JP_EPSILON: f32 = 0.0000001;

pub fn Vec2(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,
    };
}

pub const Vec3f32 = struct {
    x: f32 = undefined,
    y: f32 = undefined,
    z: f32 = undefined,

    const Self = @This();

    pub fn create_x() Self {
        return .{
            .x = 1,
            .y = 0,
            .z = 0,
        };
    }

    pub fn create_y() Self {
        return .{
            .x = 0,
            .y = 1,
            .z = 0,
        };
    }

    pub fn create_z() Self {
        return .{
            .x = 0,
            .y = 0,
            .z = 1,
        };
    }

    pub fn create_x_neg() Self {
        var tmp: Self = Self.create_x();
        return tmp.product_scalar(-1);
    }

    pub fn create_y_neg() Self {
        var tmp: Self = Self.create_y();
        return tmp.product_scalar(-1);
    }

    pub fn create_z_neg() Self {
        var tmp: Self = Self.create_z();
        return tmp.product_scalar(-1);
    }

    pub fn check_is_equal(self: Self, vec: *const Vec3f32) bool {
        return (self.x == vec.x and self.y == vec.y and self.z == vec.z);
    }

    // TODO: rename scale anrold: "atVectorAPI"
    pub fn product_scalar(self: Self, x: f32) Self {
        return Self{
            .x = x * self.x,
            .y = x * self.y,
            .z = x * self.z,
        };
    }

    pub fn product_dot(self: Self, vec: Self) f32 {
        return self.x * vec.x + self.y * vec.y + self.z * vec.z;
    }

    pub fn substract_vector(self: Self, vec: Self) Self {
        return Self{
            .x = self.x - vec.x,
            .y = self.y - vec.y,
            .z = self.z - vec.z,
        };
    }

    pub fn sum_vector(self: Self, vec: Self) Self {
        return Self{
            .x = self.x + vec.x,
            .y = self.y + vec.y,
            .z = self.z + vec.z,
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

    pub fn compute_length(self: Self) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn log_debug(self: Self) void {
        std.debug.print("\n.x :{}", .{self.x});
        std.debug.print("\n.y :{}", .{self.y});
        std.debug.print("\n.z :{}\n", .{self.z});
    }

    pub fn gen_random_hemisphere_normalized(
        self: Self,
        rand_gen: *std.rand.DefaultPrng,
    ) Self {
        var ret = Self{
            .x = rand_gen.random().float(f32) * 2 - 1,
            .y = rand_gen.random().float(f32) * 2 - 1,
            .z = rand_gen.random().float(f32) * 2 - 1,
        };
        ret = ret.normalize();
        if (self.product_dot(&ret) < JP_EPSILON) {
            ret = ret.product_scalar(-1);
        }
        return ret;
    }
};

test "vec_init_deinit" {}
