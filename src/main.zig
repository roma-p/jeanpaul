const std = @import("std");
const stdout = std.io.getStdOut().writer();

const IMG_WIDTH: u8 = 30;
const IMG_HEIGHT: u8 = 20;

pub const Img = struct {
    width: u32 = undefined,
    height: u32 = undefined,
    r: [][]u8 = undefined,
    g: [][]u8 = undefined,
    b: [][]u8 = undefined,
    a: [][]u8 = undefined,
};

pub fn main() !void {
    var img: Img = try image_create(IMG_WIDTH, IMG_HEIGHT);
    img.width = 2;
    var matrix = try matrix_create_2d_u8(3, 5);
    for (matrix) |row| {
        for (row) |value| {
            try stdout.print("{d}", .{value});
        }
        try stdout.print("\n", .{});
    }
}

fn image_create(width: u8, height: u8) !Img {
    var img = Img{
        .width = width,
        .height = height,
        .r = try matrix_create_2d_u8(width, height),
        .g = try matrix_create_2d_u8(width, height),
        .b = try matrix_create_2d_u8(width, height),
        .a = try matrix_create_2d_u8(width, height),
    };
    return img;
}

fn matrix_create_2d_u8(x: u8, y: u8) ![][]u8 {
    var matrix: [][]u8 = undefined;
    matrix = try std.heap.page_allocator.alloc([]u8, x);
    for (matrix) |*row| {
        row.* = try std.heap.page_allocator.alloc(u8, y);
        for (row.*) |_, i| {
            row.*[i] = 0;
        }
    }
    return matrix;
}
