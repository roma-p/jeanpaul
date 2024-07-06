const std = @import("std");
const gpa = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

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

pub const BoudingRectangleu16 = struct {
    x_min: u16 = undefined,
    x_max: u16 = undefined,
    y_min: u16 = undefined,
    y_max: u16 = undefined,
};

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
