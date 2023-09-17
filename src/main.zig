const std = @import("std");
const stdout = std.io.getStdOut().writer();

const rgba_img = @import("rgba_img.zig");

const IMG_WIDTH: u8 = 30;
const IMG_HEIGHT: u8 = 20;

pub fn main() !void {
    var img = try rgba_img.image_create(IMG_WIDTH, IMG_HEIGHT);
    try rgba_img.image_prompt_to_console(img);
    try rgba_img.image_delete(img);
}
