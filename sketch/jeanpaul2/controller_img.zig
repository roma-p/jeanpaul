const std = @import("std");
const allocator = std.heap.page_allocator;

const vector_matrix = @import("vector_matrix.zig");
const jp_color = @import("jp_color.zig");
const JpColor = jp_color.JpColor;
const JP_COLOR_BlACK = jp_color.JP_COLOR_BlACK;

const ControllerImg = @This();

width: u16 = undefined,
height: u16 = undefined,

al_image_layer: std.ArrayList([][]JpColor),
al_layer_name: std.ArrayList([]const u8),

pub fn init(width: u16, height: u16) ControllerImg {
    var ret = ControllerImg{
        .width = width,
        .height = height,
        .al_image_layer = std.ArrayList([][]JpColor).init(allocator),
        .al_layer_name = std.ArrayList([]const u8).init(allocator),
    };
    return ret;
}

pub fn deinit(self: *ControllerImg) void {
    self.al_image_layer.deinit();
    self.al_layer_name.deinit();
    self.* = undefined;
}

pub fn register_image_layer(self: *ControllerImg, layer_name: []const u8) !usize {
    // TODO: check if name free...
    const ret = self.al_image_layer.items.len;
    var matrix = try vector_matrix.matrix_generic_create(
        JpColor,
        JP_COLOR_BlACK,
        self.width,
        self.height,
    );
    try self.al_image_layer.append(matrix);
    try self.al_layer_name.append(layer_name);
    return ret;
}

pub fn write_ppm(
    self: *ControllerImg,
    out_dir: []const u8,
    file_name: []const u8,
) !void {
    const layer_number = self.al_image_layer.items.len;
    var thread_array = std.ArrayList(std.Thread).init(allocator);

    var i: usize = 0;
    while (i < layer_number) : (i += 1) {
        try thread_array.append(
            try std.Thread.spawn(
                .{},
                _write_ppm_single_layer,
                .{ self, out_dir, file_name, i },
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
        allocator,
        "{s}/{s}_{s}.ppm",
        .{ out_dir, file_name, self.al_layer_name.items[layer_id] },
    );
    defer allocator.free(file_path);

    const file = try std.fs.cwd().createFile(
        file_path,
        .{ .read = true },
    );
    defer file.close();

    var file_writer = file.writer();
    var buffer_writer = std.io.bufferedWriter(file_writer);
    var writer = buffer_writer.writer();

    try writer.writeAll(buffer_header_content);

    var _x: u16 = undefined;
    var _y: u16 = self.height;
    while (_y > 0) : (_y -= 1) {
        _x = 0;
        while (_x < self.width) : (_x += 1) {
            const px = self.al_image_layer.items[layer_id][_x][_y - 1];
            const buffer_line_content = try std.fmt.bufPrint(
                &buffer_line,
                "\n{} {} {}",
                .{
                    jp_color.cast_jp_color_to_u8(px.r),
                    jp_color.cast_jp_color_to_u8(px.g),
                    jp_color.cast_jp_color_to_u8(px.b),
                },
            );
            try writer.writeAll(buffer_line_content);
        }
    }
    try buffer_writer.flush();
}

// test "controller_img" {
//     var controller_img = ControllerImg.init(1920, 1080);
//     _ = try controller_img.register_image_layer("tagrossemere");
//     _ = try controller_img.register_image_layer("maislol");
//     controller_img.al_image_layer.items[0][0][0].r = 1;
//     controller_img.al_image_layer.items[0][0][0].g = 1;
//     controller_img.al_image_layer.items[0][0][0].b = 1;
//     try controller_img.write_ppm("oui", "test");
//     controller_img.deinit();
// }
