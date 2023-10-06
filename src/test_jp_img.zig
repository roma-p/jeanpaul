const std = @import("std");
const jp_img = @import("jp_img.zig");

test "matrix_create_and_delete" {
    var matrix = try jp_img.matrix_create_2d_u8(3, 2);
    matrix[0][0] = 1;
    try std.testing.expectEqual(matrix[0][0], 1);
    try jp_img.matrix_delete_2d_u8(&matrix);
}
test "image_create_and_delete" {
    var img = try jp_img.image_create(3, 2);
    img.r[0][0] = 1;
    try std.testing.expectEqual(img.r[0][0], 1);
    try jp_img.image_prompt_to_console(img);
    try jp_img.image_delete(img);
}

test "image_write_to_ppm_basic" {
    var img = try jp_img.image_create(3, 3);
    img.r[0][0] = 1;
    try jp_img.image_write_to_ppm(img, "image_write_to_ppm_basic.ppm");
    try jp_img.image_delete(img);
}
