const std = @import("std");
const matrix = @import("matrix.zig");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

pub const Img = struct {
    width: u32 = undefined,
    height: u32 = undefined,
    r: [][]u8 = undefined,
    g: [][]u8 = undefined,
    b: [][]u8 = undefined,
    a: [][]u8 = undefined,
};

pub fn image_create(width: u8, height: u8) !*Img {
    const img = try allocator.create(Img);
    img.* = Img{
        .width = width,
        .height = height,
        .r = try matrix.matrix_create_2d_u8(height, width),
        .g = try matrix.matrix_create_2d_u8(height, width),
        .b = try matrix.matrix_create_2d_u8(height, width),
        .a = try matrix.matrix_create_2d_u8(height, width),
    };
    return img;
}

pub fn image_delete(img: *Img) !void {
    try matrix.matrix_delete_2d_u8(&img.r);
    try matrix.matrix_delete_2d_u8(&img.g);
    try matrix.matrix_delete_2d_u8(&img.b);
    try matrix.matrix_delete_2d_u8(&img.a);
    allocator.destroy(img);
}

pub fn image_prompt_to_console(img: *Img) !void {
    const red_values = img.r;
    try stdout.print("\n", .{});
    for (red_values) |row| {
        for (row) |value| {
            var c: u8 = undefined;
            if (value == 0) {
                c = '.';
            } else {
                c = 'x';
            }
            try stdout.print("{c}", .{c});
        }
        try stdout.print("\n", .{});
    }
}

test "image_create_and_delete" {
    var img = try image_create(3, 2);
    img.r[0][0] = 1;
    try std.testing.expectEqual(img.r[0][0], 1);
    try image_prompt_to_console(img);
    try image_delete(img);
}
