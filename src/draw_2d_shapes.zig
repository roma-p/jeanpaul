const std = @import("std");
const math = std.math;
const types = @import("types.zig");
const rgba_img = @import("rgba_img.zig");
const stdout = std.io.getStdOut().writer();

fn min(x: u16, y: u16) u16 {
    if (x < y) return x;
    return y;
}

fn max(x: u16, y: u16) u16 {
    if (x > y) return x;
    return y;
}

const BoundingBoxRectangleError = error{OutOfImage};

pub fn compute_bounding_rectangle(
    img: *rgba_img.Img,
    pos: *const types.Vec2u32,
    size: *const types.Vec2u32,
) BoundingBoxRectangleError!types.BoudingRectangleu32 {
    const half_width: u16 = size.x / 2;
    const half_height: u16 = size.y / 2;

    // check if rectangle outside of image. (so not iterate)
    // no need to check if outside in negative side as pos can't be neg.

    if (pos.x > img.width + half_width) {
        return BoundingBoxRectangleError.OutOfImage;
    } else if (pos.y > img.height + half_height) {
        return BoundingBoxRectangleError.OutOfImage;
    }

    const origin: u16 = 0;

    var min_x: u16 = undefined;
    var min_y: u16 = undefined;

    if (half_width > pos.x) {
        min_x = origin;
    } else {
        min_x = pos.x - half_width;
    }

    if (half_height > pos.y) {
        min_y = origin;
    } else {
        min_y = pos.y - half_height;
    }

    const max_x: u16 = min(img.width - 1, pos.x + half_width - 1);
    const max_y: u16 = min(img.height - 1, pos.y + half_height - 1);

    return types.BoudingRectangleu32{
        .x_min = min_x,
        .x_max = max_x,
        .y_min = min_y,
        .y_max = max_y,
    };
}

pub fn draw_rectangle(
    img: *rgba_img.Img,
    pos: *const types.Vec2u32,
    size: *const types.Vec2u32,
    color: *const types.Color,
) void {
    var bounding_rec = compute_bounding_rectangle(img, pos, size) catch |err| {
        if (err == BoundingBoxRectangleError.OutOfImage) {
            return;
        } else {
            unreachable;
        }
    };

    var _x: u16 = bounding_rec.x_min;
    var _y: u16 = bounding_rec.y_min;

    while (_x <= bounding_rec.x_max) : (_x += 1) {
        _y = bounding_rec.y_min;
        while (_y <= bounding_rec.y_max) : (_y += 1) {
            img.r[_x][_y] = color.r;
            img.g[_x][_y] = color.g;
            img.b[_x][_y] = color.b;
        }
    }
}

pub fn draw_circle(
    img: *rgba_img.Img,
    pos: *const types.Vec2u32,
    radius: u32,
    color: *const types.Color,
) !void {
    const size = types.Vec2u32{
        .x = radius * 2,
        .y = radius * 2,
    };

    var bounding_rec = compute_bounding_rectangle(img, pos, &size) catch |err| {
        if (err == BoundingBoxRectangleError.OutOfImage) {
            return;
        } else {
            unreachable;
        }
    };

    var _x: u16 = bounding_rec.x_min;
    var _y: u16 = bounding_rec.y_min;

    const radius_square: u32 = radius * radius;

    while (_x <= bounding_rec.x_max) : (_x += 1) {
        _y = bounding_rec.y_min;
        while (_y <= bounding_rec.y_max) : (_y += 1) {
            // circle equation : (_x - pos.x)^2 + (_y - pos.y)^2 < radisu^2
            var x_square: i32 = @as(i32, _x) - @as(i32, pos.x);
            x_square = x_square * x_square;
            var y_square: i32 = @as(i32, _y) - @as(i32, pos.y);
            y_square = y_square * y_square;
            if (x_square + y_square < radius_square) {
                img.r[_x][_y] = color.r;
                img.g[_x][_y] = color.g;
                img.b[_x][_y] = color.b;
            }
        }
    }
}

// TESTS ----------------------------------------------------------------------

test "compute_bounding_rectangle_at_center" {
    var img = try rgba_img.image_create(4, 4);
    const pos = types.Vec2u32{
        .x = 2,
        .y = 2,
    };

    const size = types.Vec2u32{
        .x = 2,
        .y = 2,
    };
    const bounding_rec = try compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 1);
    try std.testing.expectEqual(bounding_rec.x_max, 2);
    try std.testing.expectEqual(bounding_rec.y_min, 1);
    try std.testing.expectEqual(bounding_rec.y_max, 2);
}

test "compute_bounding_rectangle_at_center_size_of_image" {
    var img = try rgba_img.image_create(4, 4);
    const pos = types.Vec2u32{
        .x = 2,
        .y = 2,
    };

    const size = types.Vec2u32{
        .x = 4,
        .y = 4,
    };
    const bounding_rec = try compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 0);
    try std.testing.expectEqual(bounding_rec.x_max, 3);
    try std.testing.expectEqual(bounding_rec.y_min, 0);
    try std.testing.expectEqual(bounding_rec.y_max, 3);
}

test "compute_bounding_rectangle_at_center_larger_than_image" {
    var img = try rgba_img.image_create(4, 4);
    const pos = types.Vec2u32{
        .x = 2,
        .y = 2,
    };

    const size = types.Vec2u32{
        .x = 6,
        .y = 10,
    };
    const bounding_rec = try compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 0);
    try std.testing.expectEqual(bounding_rec.x_max, 3);
    try std.testing.expectEqual(bounding_rec.y_min, 0);
    try std.testing.expectEqual(bounding_rec.y_max, 3);
}

test "compute_bounding_rectangle_larger_at_positive_angle" {
    var img = try rgba_img.image_create(4, 4);
    const pos = types.Vec2u32{
        .x = 3,
        .y = 3,
    };

    const size = types.Vec2u32{
        .x = 3,
        .y = 3,
    };
    const bounding_rec = try compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 2);
    try std.testing.expectEqual(bounding_rec.x_max, 3);
    try std.testing.expectEqual(bounding_rec.y_min, 2);
    try std.testing.expectEqual(bounding_rec.y_max, 3);
}

test "compute_bounding_rectangle_larger_at_negative_angle" {
    var img = try rgba_img.image_create(4, 4);
    const pos = types.Vec2u32{
        .x = 0,
        .y = 0,
    };

    const size = types.Vec2u32{
        .x = 4,
        .y = 4,
    };
    const bounding_rec = try compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 0);
    try std.testing.expectEqual(bounding_rec.x_max, 1);
    try std.testing.expectEqual(bounding_rec.y_min, 0);
    try std.testing.expectEqual(bounding_rec.y_max, 1);
}

test "draw_rectange_at_center_check_colors" {
    var img = try rgba_img.image_create(4, 4);

    const color = types.Color{
        .r = 15,
        .g = 30,
        .b = 255,
    };

    const pos = types.Vec2u32{
        .x = 2,
        .y = 2,
    };

    const size = types.Vec2u32{
        .x = 2,
        .y = 2,
    };

    draw_rectangle(img, &pos, &size, &color);
    // try rgba_img.image_prompt_to_console(img);

    // checking red.
    try std.testing.expectEqual(img.r[0][0], 0);
    try std.testing.expectEqual(img.r[0][1], 0);
    try std.testing.expectEqual(img.r[0][2], 0);
    try std.testing.expectEqual(img.r[0][3], 0);

    try std.testing.expectEqual(img.r[1][0], 0);
    try std.testing.expectEqual(img.r[1][1], 15);
    try std.testing.expectEqual(img.r[1][2], 15);
    try std.testing.expectEqual(img.r[1][3], 0);

    try std.testing.expectEqual(img.r[2][0], 0);
    try std.testing.expectEqual(img.r[2][1], 15);
    try std.testing.expectEqual(img.r[2][2], 15);
    try std.testing.expectEqual(img.r[2][3], 0);

    try std.testing.expectEqual(img.r[3][0], 0);
    try std.testing.expectEqual(img.r[3][1], 0);
    try std.testing.expectEqual(img.r[3][2], 0);
    try std.testing.expectEqual(img.r[3][3], 0);

    // checking green.
    try std.testing.expectEqual(img.g[0][0], 0);
    try std.testing.expectEqual(img.g[0][1], 0);
    try std.testing.expectEqual(img.g[0][2], 0);
    try std.testing.expectEqual(img.g[0][3], 0);

    try std.testing.expectEqual(img.g[1][0], 0);
    try std.testing.expectEqual(img.g[1][1], 30);
    try std.testing.expectEqual(img.g[1][2], 30);
    try std.testing.expectEqual(img.g[1][3], 0);

    try std.testing.expectEqual(img.g[2][0], 0);
    try std.testing.expectEqual(img.g[2][1], 30);
    try std.testing.expectEqual(img.g[2][2], 30);
    try std.testing.expectEqual(img.g[2][3], 0);

    try std.testing.expectEqual(img.g[3][0], 0);
    try std.testing.expectEqual(img.g[3][1], 0);
    try std.testing.expectEqual(img.g[3][2], 0);
    try std.testing.expectEqual(img.g[3][3], 0);

    // checking blue.
    try std.testing.expectEqual(img.b[0][0], 0);
    try std.testing.expectEqual(img.b[0][1], 0);
    try std.testing.expectEqual(img.b[0][2], 0);
    try std.testing.expectEqual(img.b[0][3], 0);

    try std.testing.expectEqual(img.b[1][0], 0);
    try std.testing.expectEqual(img.b[1][1], 255);
    try std.testing.expectEqual(img.b[1][2], 255);
    try std.testing.expectEqual(img.b[1][3], 0);

    try std.testing.expectEqual(img.b[2][0], 0);
    try std.testing.expectEqual(img.b[2][1], 255);
    try std.testing.expectEqual(img.b[2][2], 255);
    try std.testing.expectEqual(img.b[2][3], 0);

    try std.testing.expectEqual(img.b[3][0], 0);
    try std.testing.expectEqual(img.b[3][1], 0);
    try std.testing.expectEqual(img.b[3][2], 0);
    try std.testing.expectEqual(img.b[3][3], 0);
}

test "draw_circle_at_center" {
    var img = try rgba_img.image_create(50, 50);

    const color = types.Color{
        .r = 15,
        .g = 30,
        .b = 255,
    };

    const pos = types.Vec2u32{
        .x = 30,
        .y = 40,
    };
    const center = 22;
    try draw_circle(img, &pos, center, &color);
    try rgba_img.image_write_to_ppm(img);
    // try rgba_img.image_prompt_to_console(img);
}
