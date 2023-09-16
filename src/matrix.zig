const std = @import("std");

const allocator = std.heap.page_allocator;

pub fn matrix_create_2d_u8(x: u8, y: u8) ![][]u8 {
    var matrix: [][]u8 = try allocator.alloc([]u8, x);
    for (matrix) |*row| {
        row.* = try allocator.alloc(u8, y);
        for (row.*, 0..) |_, i| {
            row.*[i] = 0;
        }
    }
    return matrix;
}

pub fn matrix_delete_2d_u8(matrix: *[][]u8) !void {
    for (matrix.*) |*row| {
        allocator.free(row.*);
    }
    allocator.free(matrix.*);
}

test "matrix_create_and_delete" {
    var matrix = try matrix_create_2d_u8(3, 2);
    matrix[0][0] = 1;
    try std.testing.expectEqual(matrix[0][0], 1);
    try matrix_delete_2d_u8(&matrix);
}
