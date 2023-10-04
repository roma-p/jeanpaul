const std = @import("std");
const types = @import("types.zig");
const color_module = @import("color.zig");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

// axis used by the image are:
//
//  y
//  ^
//  |
//  * -> x

pub const Img = struct {
    width: u16 = undefined,
    height: u16 = undefined,
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
        .r = try matrix_create_2d_u8(width, height),
        .g = try matrix_create_2d_u8(width, height),
        .b = try matrix_create_2d_u8(width, height),
        .a = try matrix_create_2d_u8(width, height),
    };
    return img;
}

pub fn image_delete(img: *Img) !void {
    try matrix_delete_2d_u8(&img.r);
    try matrix_delete_2d_u8(&img.g);
    try matrix_delete_2d_u8(&img.b);
    try matrix_delete_2d_u8(&img.a);
    allocator.destroy(img);
}

// axis to print on console are.
//
//  * -> x
//  |
//  v y
pub fn image_prompt_to_console(img: *Img) !void {
    var _x: u16 = 0;
    var _y: u16 = undefined;

    while (_x < img.width) : (_x += 1) {
        _y = img.height - 1;
        while (_y != 0) : (_y -= 1) {
            var value: u8 = img.r[_x][_y];
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

// axis on ppm are.
//
//  * -> x
//  |
//  v y
pub fn image_write_to_ppm(img: *Img) !void {
    const file = try std.fs.cwd().createFile(
        "junk_file2.ppm",
        .{ .read = true },
    );
    defer file.close();

    const header = try std.fmt.allocPrint(
        allocator,
        "P3\n{d} {d}\n255\n",
        .{ img.height, img.width },
    );
    try file.writeAll(header);
    defer allocator.free(header);

    var _x: u16 = 0;
    var _y: u16 = undefined;

    while (_x < img.width) : (_x += 1) {
        _y = img.height - 1;
        while (_y != 0) : (_y -= 1) {
            const line = try std.fmt.allocPrint(
                allocator,
                "\n{} {} {}",
                .{
                    img.r[_x][_y],
                    img.g[_x][_y],
                    img.b[_x][_y],
                },
            );
            try file.writeAll(line);
            defer allocator.free(line);
        }
    }
}

pub fn image_draw_at_px(img: *Img, x: u16, y: u16, color: *color_module.Color) !*Img {
    // TODO HANDLE ERROR OUT OF RANGE!
    img.r[x][y] = color.x;
    img.g[x][y] = color.x;
    img.b[x][y] = color.x;
    img.a[x][y] = color.x;
    return img;
}

fn matrix_create_2d_u8(x: u8, y: u8) ![][]u8 {
    var matrix: [][]u8 = try allocator.alloc([]u8, x);
    for (matrix) |*row| {
        row.* = try allocator.alloc(u8, y);
        for (row.*, 0..) |_, i| {
            row.*[i] = 0;
        }
    }
    return matrix;
}

fn matrix_delete_2d_u8(matrix: *[][]u8) !void {
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
test "image_create_and_delete" {
    var img = try image_create(3, 2);
    img.r[0][0] = 1;
    try std.testing.expectEqual(img.r[0][0], 1);
    try image_prompt_to_console(img);
    try image_delete(img);
}

test "image_write_to_ppm_basic" {
    var img = try image_create(3, 3);
    img.r[0][0] = 1;
    try image_write_to_ppm(img);
    try image_delete(img);
}
