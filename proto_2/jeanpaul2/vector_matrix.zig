const std = @import("std");
const allocator = std.heap.page_allocator;

// ==== RUN TIME SIZE RAW MATRIX / VECTOR ====================================

pub fn matrix_generic_create(comptime T: type, default: T, x: u16, y: u16) ![][]T {
    var matrix: [][]T = try allocator.alloc([]T, x);
    for (matrix) |*row| {
        row.* = try allocator.alloc(T, y);
        for (row.*, 0..) |_, i| {
            row.*[i] = default;
        }
    }
    return matrix;
}

pub fn matrix_f32_delete(matrix: *[][]f32) void {
    for (matrix.*) |*row| {
        allocator.free(row.*);
    }
    allocator.free(matrix.*);
}

pub fn matrix_generic_delete(comptime T: type, matrix: *[][]T) void {
    for (matrix.*) |*row| {
        allocator.free(row.*);
    }
    allocator.free(matrix.*);
}

test "matrix_generic_create" {
    var t = try matrix_generic_create(f32, 0, 5, 4);
    matrix_generic_delete(f32, &t);

    const TEST_STRUCT = struct {
        a: u16 = 0,
        b: u32 = 1,
    };
    var u = try matrix_generic_create(TEST_STRUCT, TEST_STRUCT{}, 5, 4);
    matrix_generic_delete(TEST_STRUCT, &u);
}
