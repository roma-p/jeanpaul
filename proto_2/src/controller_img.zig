const std = @import("std");
const gpa = std.heap.page_allocator;

const Thread = std.Thread;
const Mutex = Thread.Mutex;

const maths_mat = @import("maths_mat.zig");
const maths_vec = @import("maths_vec.zig");
const data_color = @import("data_color.zig");
const data_img = @import("data_img.zig");

const utils_draw_2d = @import("utils_draw_2d.zig");
const data_render_settings = @import("data_render_settings.zig");

const Color = data_color.Color;
const ColorSpace = data_render_settings.ColorSpace;

pub const ControllerImg = @This();

width: u16 = undefined,
height: u16 = undefined,

array_image_layer: std.ArrayList(*data_img.Img),
array_layer_name: std.ArrayList([]const u8),

const ErrorControllerImg = error{ NameAlreadyTaken, InvalidPixel };

pub fn init(width: u16, height: u16) ControllerImg {
    const ret = ControllerImg{
        .width = width,
        .height = height,
        .array_image_layer = std.ArrayList(*data_img.Img).init(gpa),
        .array_layer_name = std.ArrayList([]const u8).init(gpa),
    };
    return ret;
}

pub fn deinit(self: *ControllerImg) void {
    for (self.array_image_layer.items) |matrix| {
        matrix.deinit(&gpa);
    }
    self.array_layer_name.deinit();
    self.* = undefined;
}

pub fn register_image_layer(
    self: *ControllerImg,
    layer_name: []const u8,
) !usize {
    for (self.array_layer_name.items) |v| {
        if (std.mem.eql(u8, v, layer_name)) {
            return ErrorControllerImg.NameAlreadyTaken;
        }
    }
    const ret = self.array_image_layer.items.len;
    const m = try gpa.create(data_img.Img);
    m.* = data_img.Img.init(
        self.width,
        self.height,
        data_color.COLOR_BlACK,
        &gpa,
    );
    try self.array_image_layer.append(m);
    try self.array_layer_name.append(layer_name);
    return ret;
}

pub fn write_to_px(
    self: *ControllerImg,
    x: u16,
    y: u16,
    layer_index: usize,
    c: Color,
) ErrorControllerImg!void {
    if (x >= self.width or y >= self.height) {
        return ErrorControllerImg.InvalidPixel;
    }
    self.array_image_layer.items[layer_index].*.data[x][y] = c;
}

pub fn write_ppm(
    self: *ControllerImg,
    out_dir: []const u8,
    file_name: []const u8,
    color_space: ColorSpace,
) !void {
    const layer_number = self.array_image_layer.items.len;
    var thread_array = std.ArrayList(std.Thread).init(gpa);
    defer thread_array.deinit(); // FIX ME

    var i: usize = 0;
    while (i < layer_number) : (i += 1) {
        try thread_array.append(
            try std.Thread.spawn(
                .{},
                _write_ppm_single_layer,
                .{ self, out_dir, file_name, color_space, i },
            ),
        );
    }
    i = 0;
    while (i < layer_number) : (i += 1) {
        thread_array.items[i].join();
    }
}

fn _write_ppm_single_layer(
    self: *ControllerImg,
    out_dir: []const u8,
    file_name: []const u8,
    color_space: ColorSpace,
    layer_id: usize,
) !void {
    var buffer_header: [256]u8 = undefined;
    const buffer_header_content = try std.fmt.bufPrint(
        &buffer_header,
        "P3\n{d} {d}\n255\n",
        .{ self.width, self.height },
    );
    var buffer_line: [256]u8 = undefined;

    const file_path = try std.fmt.allocPrint(
        gpa,
        "{s}/{s}_{s}.ppm",
        .{ out_dir, file_name, self.array_layer_name.items[layer_id] },
    );
    defer gpa.free(file_path);

    const file = try std.fs.cwd().createFile(
        file_path,
        .{ .read = true },
    );
    defer file.close();

    const file_writer = file.writer();
    var buffer_writer = std.io.bufferedWriter(file_writer);
    var writer = buffer_writer.writer();

    try writer.writeAll(buffer_header_content);

    var _x: u16 = undefined;
    var _y: u16 = self.height;
    while (_y > 0) : (_y -= 1) {
        _x = 0;
        while (_x < self.width) : (_x += 1) {
            const px = self.array_image_layer.items[layer_id].*.data[_x][_y - 1];
            const calibrated_px = _calibrate_to_color_space_pixel_color(px, color_space);
            const buffer_line_content = try std.fmt.bufPrint(
                &buffer_line,
                "\n{} {} {}",
                .{
                    data_color.cast_jp_color_to_u8(calibrated_px.r),
                    data_color.cast_jp_color_to_u8(calibrated_px.g),
                    data_color.cast_jp_color_to_u8(calibrated_px.b),
                },
            );
            try writer.writeAll(buffer_line_content);
        }
    }
    try buffer_writer.flush();
}

fn _calibrate_to_color_space_pixel_color(color: Color, color_space: ColorSpace) Color {
    return switch (color_space) {
        .DefaultLinear => color,
        .DefaultGamma2 => utils_draw_2d.calibrate_color_from_defaultlinear_to_defaultgamma2(color),
    };
}

test "controller_img" {
    var controller_img = ControllerImg.init(1920, 1080);
    _ = try controller_img.register_image_layer("layer_1");
    _ = try controller_img.register_image_layer("layer_2");
    controller_img.array_image_layer.items[0].*.data[0][0].r = 1;
    controller_img.array_image_layer.items[0].*.data[0][0].g = 1;
    controller_img.array_image_layer.items[0].*.data[0][0].b = 1;
    try controller_img.write_to_px(1, 1, 1, data_color.COLOR_RED);

    utils_draw_2d.draw_circle(
        controller_img.array_image_layer.items[0],
        maths_vec.Vec2u16{ .x = 1000, .y = 200 },
        250,
        data_color.COLOR_GREEN,
    );
    utils_draw_2d.draw_rectangle(
        controller_img.array_image_layer.items[0],
        maths_vec.Vec2u16{ .x = 300, .y = 700 },
        maths_vec.Vec2u16{ .x = 400, .y = 500 },
        data_color.COLOR_RED,
    );

    try controller_img.write_ppm("tests", "test", ColorSpace.DefaultLinear);
    controller_img.deinit();
}
