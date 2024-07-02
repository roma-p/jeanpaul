const std = @import("std");
const gpa = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

pub const JP_EPSILON: f32 = 0.0000001;

// -- MATRIX -----------------------------------------------------------------

pub fn Matrix(comptime T: type) type {
    return struct {
        data: [][]T = undefined,
        width: u32,
        height: u32,

        const Self = @This(); // equivalent to Matrix(T)

        pub fn init(
            width: u32,
            height: u32,
            default: T,
            allocator: *const Allocator,
        ) Self {
            const data = allocator.alloc([]T, width) catch unreachable;

            var i: usize = 0;
            var j: usize = 0;

            while (i < width) {
                data[i] = allocator.alloc(T, height) catch unreachable;
                while (j < height) {
                    data[i][j] = default;
                    j += 1;
                }
                i += 1;
            }

            return .{
                .width = width,
                .height = height,
                .data = data,
            };
        }

        pub fn deinit(self: *Self, allocator: *const Allocator) void {
            var i: usize = 0;
            while (i < self.width) {
                allocator.free(self.data[i]);
                i += 1;
            }
            allocator.free(self.data);
        }
    };
}

test "matrix_init_deinit" {
    const matrix_1 = try gpa.create(Matrix(f32));
    const matrix_2 = try gpa.create(Matrix(f32));
    const matrix_3 = try gpa.create(Matrix(f32));
    matrix_1.* = Matrix(f32).init(3, 3, 2, &gpa);
    matrix_2.* = Matrix(f32).init(3, 3, 2, &gpa);
    matrix_3.* = Matrix(f32).init(3, 3, 2, &gpa);
    var matrix_vec: [3]*Matrix(f32) = undefined;
    matrix_vec[0] = matrix_1;
    matrix_vec[1] = matrix_2;
    matrix_vec[2] = matrix_3;
    matrix_1.*.data[0][0] = 3;
    for (matrix_vec) |m| {
        m.deinit(&gpa);
    }
}

// -- Vec3f32 ----------------------------------------------------------------

pub const Vec3f32 = struct {
    x: f32 = undefined,
    y: f32 = undefined,
    z: f32 = undefined,

    pub fn check_is_equal(self: *const Vec3f32, vec: *const Vec3f32) bool {
        return (self.x == vec.x and self.y == vec.y and self.z == vec.z);
    }

    // TODO: rename scale anrold: "atVectorAPI"
    pub fn product_scalar(self: *const Vec3f32, x: f32) Vec3f32 {
        return Vec3f32{
            .x = x * self.x,
            .y = x * self.y,
            .z = x * self.z,
        };
    }

    pub fn product_dot(self: *const Vec3f32, vec: *const Vec3f32) f32 {
        return self.x * vec.x + self.y * vec.y + self.z * vec.z;
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

    pub fn normalize(self: *const Vec3f32) Vec3f32 {
        const magnitude = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        return Vec3f32{
            .x = self.x / magnitude,
            .y = self.y / magnitude,
            .z = self.z / magnitude,
        };
    }

    pub fn compute_length(self: *const Vec3f32) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn log_debug(self: *const Vec3f32) void {
        std.debug.print("\n.x :{}", .{self.x});
        std.debug.print("\n.y :{}", .{self.y});
        std.debug.print("\n.z :{}\n", .{self.z});
    }

    pub fn gen_random_hemisphere_normalized(
        self: *const Vec3f32,
        rand_gen: *std.rand.DefaultPrng,
    ) Vec3f32 {
        var ret = Vec3f32{
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
