const std = @import("std");
const data_img = @import("data_img.zig");
const data_color = @import("data_color.zig");
const maths_vec = @import("maths_vec.zig");
const maths_mat = @import("maths_mat.zig");

const Img = data_img.Img;
const Color = data_color.Color;
const Vec2u16 = maths_vec.Vec2u16;
const BoudingRectangleu16 = maths_mat.BoudingRectangleu16;

const BoundingBoxRectangleError = error{OutOfImage};

pub fn draw_rectangle(img: *Img, pos: Vec2u16, size: Vec2u16, color: Color) void {
    const bounding_rec = _compute_bounding_rectangle(img, pos, size) catch |err| {
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
            img.data[_x][_y].r = color.r;
            img.data[_x][_y].g = color.g;
            img.data[_x][_y].b = color.b;
        }
    }
}

pub fn draw_circle(img: *Img, pos: Vec2u16, radius: u16, color: Color) void {
    const size = Vec2u16{
        .x = radius * 2,
        .y = radius * 2,
    };

    const bounding_rec = _compute_bounding_rectangle(img, pos, size) catch |err| {
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
                img.data[_x][_y].r = color.r;
                img.data[_x][_y].g = color.g;
                img.data[_x][_y].b = color.b;
            }
        }
    }
}

pub fn auto_clamp_img(img: *Img) void {
    var max_value: f32 = 0;
    var x: usize = 0;
    var y: usize = 0;
    while (x < img.width) : (x += 1) {
        y = 0;
        while (y < img.height) : (y += 1) {
            const v = img.data[x][y];
            if (v.r > max_value) max_value = v.r;
            if (v.g > max_value) max_value = v.g;
            if (v.b > max_value) max_value = v.b;
        }
    }
    x = 0;
    while (x < img.width) : (x += 1) {
        y = 0;
        while (y < img.height) : (y += 1) {
            img.data[x][y].r = img.data[x][y].r / max_value;
            img.data[x][y].g = img.data[x][y].g / max_value;
            img.data[x][y].b = img.data[x][y].b / max_value;
        }
    }
}

fn _compute_bounding_rectangle(
    img: *Img,
    pos: Vec2u16,
    size: Vec2u16,
) BoundingBoxRectangleError!BoudingRectangleu16 {
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

    const max_x: u16 = @min(img.width - 1, pos.x + half_width - 1);
    const max_y: u16 = @min(img.height - 1, pos.y + half_height - 1);

    return BoudingRectangleu16{
        .x_min = min_x,
        .x_max = max_x,
        .y_min = min_y,
        .y_max = max_y,
    };
}
