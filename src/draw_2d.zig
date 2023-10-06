const std = @import("std");
const stdout = std.io.getStdOut().writer();
const math = std.math;
const types = @import("types.zig");
const jp_color = @import("jp_color.zig");
const jp_img = @import("jp_img.zig");

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
    img: *jp_img.JpImg,
    pos: *const types.Vec2u16,
    size: *const types.Vec2u16,
) BoundingBoxRectangleError!types.BoudingRectangleu16 {
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

    return types.BoudingRectangleu16{
        .x_min = min_x,
        .x_max = max_x,
        .y_min = min_y,
        .y_max = max_y,
    };
}

pub fn draw_rectangle(
    img: *jp_img.JpImg,
    pos: *const types.Vec2u16,
    size: *const types.Vec2u16,
    color: *const jp_color.JpColor,
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
    img: *jp_img.JpImg,
    pos: *const types.Vec2u16,
    radius: u16,
    color: *const jp_color.JpColor,
) !void {
    const size = types.Vec2u16{
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
