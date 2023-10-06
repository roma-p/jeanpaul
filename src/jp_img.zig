const std = @import("std");
const types = @import("types.zig");
const jp_color = @import("jp_color.zig");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

// axis used by the image are:
//
//  y
//  ^
//  |
//  * -> x

pub const JpImg = struct {
    width: u16 = undefined,
    height: u16 = undefined,
    r: [][]u8 = undefined,
    g: [][]u8 = undefined,
    b: [][]u8 = undefined,
    a: [][]u8 = undefined,
};

pub fn image_create(width: u16, height: u16) !*JpImg {
    const img = try allocator.create(JpImg);
    img.* = JpImg{
        .width = width,
        .height = height,
        .r = try matrix_create_2d_u8(width, height),
        .g = try matrix_create_2d_u8(width, height),
        .b = try matrix_create_2d_u8(width, height),
        .a = try matrix_create_2d_u8(width, height),
    };
    return img;
}

pub fn image_delete(img: *JpImg) !void {
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
pub fn image_prompt_to_console(img: *JpImg) !void {
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
pub fn image_write_to_ppm(img: *JpImg, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(
        filename,
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
        _y = img.height;
        while (_y > 0) : (_y -= 1) {
            const line = try std.fmt.allocPrint(
                allocator,
                "\n{} {} {}",
                .{
                    img.r[_x][_y - 1],
                    img.g[_x][_y - 1],
                    img.b[_x][_y - 1],
                },
            );
            try file.writeAll(line);
            defer allocator.free(line);
        }
    }
}

pub fn image_draw_at_px(img: *JpImg, x: u16, y: u16, color: jp_color.JpColor) !void {
    // TODO HANDLE ERROR OUT OF RANGE!
    img.r[x][y] = color.r;
    img.g[x][y] = color.g;
    img.b[x][y] = color.b;
}

pub fn matrix_create_2d_u8(x: u16, y: u16) ![][]u8 {
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
