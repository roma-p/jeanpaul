const std = @import("std");
const draw_2d = @import("draw_2d.zig");
const jp_img = @import("jp_img.zig");
const jp_color = @import("jp_color.zig");
const types = @import("types.zig");

const JpImg = jp_img.JpImg;

test "draw_2d.compute_bounding_rectangle_at_center" {
    var img = try JpImg.new(4, 4);
    const pos = types.Vec2u16{
        .x = 2,
        .y = 2,
    };

    const size = types.Vec2u16{
        .x = 2,
        .y = 2,
    };
    const bounding_rec = try draw_2d.compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 1);
    try std.testing.expectEqual(bounding_rec.x_max, 2);
    try std.testing.expectEqual(bounding_rec.y_min, 1);
    try std.testing.expectEqual(bounding_rec.y_max, 2);
}

test "draw_2d.compute_bounding_rectangle_at_center_size_of_image" {
    var img = try JpImg.new(4, 4);
    const pos = types.Vec2u16{
        .x = 2,
        .y = 2,
    };

    const size = types.Vec2u16{
        .x = 4,
        .y = 4,
    };
    const bounding_rec = try draw_2d.compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 0);
    try std.testing.expectEqual(bounding_rec.x_max, 3);
    try std.testing.expectEqual(bounding_rec.y_min, 0);
    try std.testing.expectEqual(bounding_rec.y_max, 3);
}

test "draw_2d.compute_bounding_rectangle_at_center_larger_than_image" {
    var img = try JpImg.new(4, 4);
    const pos = types.Vec2u16{
        .x = 2,
        .y = 2,
    };

    const size = types.Vec2u16{
        .x = 6,
        .y = 10,
    };
    const bounding_rec = try draw_2d.compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 0);
    try std.testing.expectEqual(bounding_rec.x_max, 3);
    try std.testing.expectEqual(bounding_rec.y_min, 0);
    try std.testing.expectEqual(bounding_rec.y_max, 3);
}

test "draw_2d.compute_bounding_rectangle_larger_at_positive_angle" {
    var img = try JpImg.new(4, 4);
    const pos = types.Vec2u16{
        .x = 3,
        .y = 3,
    };

    const size = types.Vec2u16{
        .x = 3,
        .y = 3,
    };
    const bounding_rec = try draw_2d.compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 2);
    try std.testing.expectEqual(bounding_rec.x_max, 3);
    try std.testing.expectEqual(bounding_rec.y_min, 2);
    try std.testing.expectEqual(bounding_rec.y_max, 3);
}

test "draw_2d.compute_bounding_rectangle_larger_at_negative_angle" {
    var img = try JpImg.new(4, 4);
    const pos = types.Vec2u16{
        .x = 0,
        .y = 0,
    };

    const size = types.Vec2u16{
        .x = 4,
        .y = 4,
    };
    const bounding_rec = try draw_2d.compute_bounding_rectangle(img, &pos, &size);
    try std.testing.expectEqual(bounding_rec.x_min, 0);
    try std.testing.expectEqual(bounding_rec.x_max, 1);
    try std.testing.expectEqual(bounding_rec.y_min, 0);
    try std.testing.expectEqual(bounding_rec.y_max, 1);
}

test "draw_rectange_at_center_check_colors" {
    var img = try JpImg.new(4, 4);

    const color = jp_color.JpColor{
        .r = 0.1,
        .g = 0.3,
        .b = 1,
    };

    const pos = types.Vec2u16{
        .x = 2,
        .y = 2,
    };

    const size = types.Vec2u16{
        .x = 2,
        .y = 2,
    };

    draw_2d.draw_rectangle(img, &pos, &size, &color);

    // checking red.
    try std.testing.expectEqual(img.r[0][0], 0);
    try std.testing.expectEqual(img.r[0][1], 0);
    try std.testing.expectEqual(img.r[0][2], 0);
    try std.testing.expectEqual(img.r[0][3], 0);

    try std.testing.expectEqual(img.r[1][0], 0);
    try std.testing.expectEqual(img.r[1][1], 0.1);
    try std.testing.expectEqual(img.r[1][2], 0.1);
    try std.testing.expectEqual(img.r[1][3], 0);

    try std.testing.expectEqual(img.r[2][0], 0);
    try std.testing.expectEqual(img.r[2][1], 0.1);
    try std.testing.expectEqual(img.r[2][2], 0.1);
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
    try std.testing.expectEqual(img.g[1][1], 0.3);
    try std.testing.expectEqual(img.g[1][2], 0.3);
    try std.testing.expectEqual(img.g[1][3], 0);

    try std.testing.expectEqual(img.g[2][0], 0);
    try std.testing.expectEqual(img.g[2][1], 0.3);
    try std.testing.expectEqual(img.g[2][2], 0.3);
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
    try std.testing.expectEqual(img.b[1][1], 1);
    try std.testing.expectEqual(img.b[1][2], 1);
    try std.testing.expectEqual(img.b[1][3], 0);

    try std.testing.expectEqual(img.b[2][0], 0);
    try std.testing.expectEqual(img.b[2][1], 1);
    try std.testing.expectEqual(img.b[2][2], 1);
    try std.testing.expectEqual(img.b[2][3], 0);

    try std.testing.expectEqual(img.b[3][0], 0);
    try std.testing.expectEqual(img.b[3][1], 0);
    try std.testing.expectEqual(img.b[3][2], 0);
    try std.testing.expectEqual(img.b[3][3], 0);
}

test "draw_circle_at_center" {
    var img = try JpImg.new(50, 50);

    const color = jp_color.JpColor{
        .r = 0.1,
        .g = 0.3,
        .b = 1,
    };

    const pos = types.Vec2u16{
        .x = 30,
        .y = 40,
    };
    const center = 22;
    try draw_2d.draw_circle(img, &pos, center, &color);
    try img.image_write_to_ppm("draw_circle_at_center.ppm");
}
