const std = @import("std");
const gpa = std.heap.page_allocator;

const Thread = std.Thread;
const Mutex = Thread.Mutex;

const maths_mat = @import("maths_mat.zig");
const data_color = @import("data_color.zig");
const data_img = @import("data_img.zig");

pub const ControllerImg = @This();

width: u16 = undefined,
height: u16 = undefined,
mutex_write_to_img: Mutex = undefined,

array_image_layer: std.ArrayList(*data_img.Img),
array_layer_name: std.ArrayList([]const u8),

pub fn init(width: u16, height: u16) ControllerImg {
    const ret = ControllerImg{
        .width = width,
        .height = height,
        .array_image_layer = std.ArrayList(*data_img.Img).init(gpa),
        .array_layer_name = std.ArrayList([]const u8).init(gpa),
        .mutex_write_to_img = Mutex{},
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
    // TODO: check if name free...
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

pub fn write_to_px_thread_safe(
    self: *ControllerImg,
    x: u16,
    y: u16,
    c: data_color.Color,
) void {
    self.mutex_write_to_img.lock();
    defer self.mutex_write_to_img.unlock();
    // tmp method, no layer...
    self.array_image_layer.items[0].*.data[x][y] = c;
}

pub fn write_to_px(
    self: *ControllerImg,
    x: u16,
    y: u16,
    layer_index: usize,
    c: data_color.Color,
) void {
    // TODO: check layer_index < len !!!!!
    self.array_image_layer.items[layer_index].*.data[x][y] = c;
}

pub fn write_ppm(
    self: *ControllerImg,
    out_dir: []const u8,
    file_name: []const u8,
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
            const buffer_line_content = try std.fmt.bufPrint(
                &buffer_line,
                "\n{} {} {}",
                .{
                    data_color.cast_jp_color_to_u8(px.r),
                    data_color.cast_jp_color_to_u8(px.g),
                    data_color.cast_jp_color_to_u8(px.b),
                },
            );
            try writer.writeAll(buffer_line_content);
        }
    }
    try buffer_writer.flush();
}

test "controller_img" {
    var controller_img = ControllerImg.init(1920, 1080);
    _ = try controller_img.register_image_layer("layer_1");
    _ = try controller_img.register_image_layer("layer_2");
    controller_img.array_image_layer.items[0].*.data[0][0].r = 1;
    controller_img.array_image_layer.items[0].*.data[0][0].g = 1;
    controller_img.array_image_layer.items[0].*.data[0][0].b = 1;
    try controller_img.write_ppm("tests", "test");
    controller_img.deinit();
}
