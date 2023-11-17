const std = @import("std");
const jp_img = @import("jp_img.zig");

const JpImg = jp_img.JpImg;

test "image_create_and_delete" {
    var img = try JpImg.new(3, 2);
    img.r[0][0] = 1;
    try std.testing.expectEqual(img.r[0][0], 1);
    try img.image_prompt_to_console();
    img.delete();
}

test "image_write_to_ppm_basic" {
    var img = try JpImg.new(8, 3);
    img.r[0][0] = 1;
    try img.image_write_to_ppm("image_write_to_ppm_basic.ppm");
    img.delete();
}
