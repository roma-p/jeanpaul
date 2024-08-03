const std = @import("std");
const maths_vec = @import("maths_vec.zig");
const maths_mat = @import("maths_mat.zig");

pub fn calculate_tile_number(
    width: u16,
    height: u16,
    tile_size: u16,
) maths_vec.Vec2(u16) {
    var x_number = width / tile_size;
    if (x_number * tile_size < width) {
        x_number += 1;
    }
    var y_number = height / tile_size;
    if (y_number * tile_size < height) {
        y_number += 1;
    }
    return maths_vec.Vec2(u16){ .x = x_number, .y = y_number };
}

// TODO: center mode && triangle mode.
pub fn get_tile_bouding_rectangle_line_mode(
    tile_number_x: u16,
    tile_id: u16,
    tile_size: u16,
    image_width: u16,
    image_height: u16,
) maths_mat.BoudingRectangleu16 {
    const x_index: u16 = @rem(tile_id, tile_number_x);
    const y_index: u16 = tile_id / (tile_number_x);
    const ret = maths_mat.BoudingRectangleu16{
        .x_min = x_index * tile_size,
        .x_max = @min(x_index * tile_size + tile_size - 1, image_width - 1),
        .y_min = y_index * tile_size,
        .y_max = @min(y_index * tile_size + tile_size - 1, image_height - 1),
    };
    return ret;
}

pub fn get_tile_pixel_number(bouding_rectangle: maths_mat.BoudingRectangleu16) u16 {
    const x_number = bouding_rectangle.x_max - bouding_rectangle.x_min;
    const y_number = bouding_rectangle.y_max - bouding_rectangle.y_min;
    const ret = @mulWithOverflow(x_number, y_number).@"0";
    return ret;
}

// -- Tests ------------------------------------------------------------------

test "u_tiling" {
    const tile_info = calculate_tile_number(1920, 1080, 64);
    try std.testing.expectEqual(30, tile_info.x);
    try std.testing.expectEqual(17, tile_info.y);

    const bounding_rectangle_1 = get_tile_bouding_rectangle_line_mode(
        tile_info.x,
        0,
        64,
        1920,
        1080,
    );
    try std.testing.expectEqual(0, bounding_rectangle_1.x_min);
    try std.testing.expectEqual(63, bounding_rectangle_1.x_max);
    try std.testing.expectEqual(0, bounding_rectangle_1.y_min);
    try std.testing.expectEqual(63, bounding_rectangle_1.y_max);

    const bounding_rectangle_2 = get_tile_bouding_rectangle_line_mode(
        tile_info.x,
        52,
        64,
        1920,
        1080,
    );
    try std.testing.expectEqual(1408, bounding_rectangle_2.x_min);
    try std.testing.expectEqual(1471, bounding_rectangle_2.x_max);
    try std.testing.expectEqual(64, bounding_rectangle_2.y_min);
    try std.testing.expectEqual(127, bounding_rectangle_2.y_max);
}
