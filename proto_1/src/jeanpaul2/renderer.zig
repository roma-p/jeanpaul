const std = @import("std");
const ControllerImg = @import("controller_img.zig");
const allocator = std.heap.page_allocator;

// TMP
const jp_color = @import("jp_color.zig");

const Renderer = @This();

render_option: RenderOption = undefined,
controller_img: ControllerImg = undefined,

_sample_number: u16 = undefined,
_sample_number_inverse: f32 = undefined,

const RenderOption = struct {
    samples_number: u8 = 2,
    width: u16 = 480,
    height: u16 = 320,
};

const RenderDestination = struct {
    out_directory: []const u8 = undefined,
    out_img_name: []const u8 = undefined,
};

pub fn init(render_option: RenderOption) !Renderer {
    var ret = Renderer{
        .render_option = render_option,
        .controller_img = ControllerImg.init(
            render_option.width,
            render_option.height,
        ),
        ._sample_number = std.math.pow(u16, 2, render_option.samples_number),
    };
    const sample_number_as_f32: f32 = @floatFromInt(ret._sample_number);
    ret._sample_number_inverse = 1 / sample_number_as_f32;

    _ = try ret.controller_img.register_image_layer("beauty");
    _ = try ret.controller_img.register_image_layer("alpha");
    _ = try ret.controller_img.register_image_layer("diffuse_albedo");
    _ = try ret.controller_img.register_image_layer("diffuse_direct");
    _ = try ret.controller_img.register_image_layer("diffuse_indirect");
    _ = try ret.controller_img.register_image_layer("specular_albedo");
    _ = try ret.controller_img.register_image_layer("specular_direct");
    _ = try ret.controller_img.register_image_layer("specular_indirect");
    _ = try ret.controller_img.register_image_layer("transmission_albedo");
    _ = try ret.controller_img.register_image_layer("transmission_direct");
    _ = try ret.controller_img.register_image_layer("transmission_indirect");

    return ret;
}

pub fn deinit(self: *Renderer) void {
    self.controller_img.deinit();
    self.* = undefined;
}

pub fn render(self: *Renderer, render_destination: RenderDestination) void {
    _ = render_destination;
    var _x: u16 = 0;
    var _y: u16 = undefined;

    const width = self.controller_img.width;
    const height = self.controller_img.height;

    while (_x < width) : (_x += 1) {
        _y = height;
        while (_y != 0) : (_y -= 1) {
            self.render_pixel_do_every_sample(_x, _y - 1);
        }
    }
}

pub fn render_pixel_do_every_sample(self: *Renderer, x: u16, y: u16) void {
    var _sample: usize = 0;
    while (_sample < self._sample_number) : (_sample += 1) {
        var diffuse_d = jp_color.JP_COLOR_GREEN;
        var diffuse_id = jp_color.JP_COLOR_BLUE;
        var alpha = jp_color.JP_COLOR_WHITE;
        var beauty_color = diffuse_d.sum_color(diffuse_id);

        diffuse_d = diffuse_d.multiply(self._sample_number_inverse);
        diffuse_id = diffuse_id.multiply(self._sample_number_inverse);
        alpha = alpha.multiply(self._sample_number_inverse);
        beauty_color = beauty_color.multiply(self._sample_number_inverse);

        self.controller_img.al_image_layer.items[0][x][y] = self.controller_img.al_image_layer.items[0][x][y].sum_color(beauty_color);
        self.controller_img.al_image_layer.items[1][x][y] = self.controller_img.al_image_layer.items[1][x][y].sum_color(alpha);
        self.controller_img.al_image_layer.items[2][x][y] = self.controller_img.al_image_layer.items[2][x][y].sum_color(diffuse_d);
        self.controller_img.al_image_layer.items[3][x][y] = self.controller_img.al_image_layer.items[3][x][y].sum_color(diffuse_id);
        self.controller_img.al_image_layer.items[4][x][y] = self.controller_img.al_image_layer.items[4][x][y].sum_color(diffuse_id);
        self.controller_img.al_image_layer.items[5][x][y] = self.controller_img.al_image_layer.items[5][x][y].sum_color(diffuse_id);
        self.controller_img.al_image_layer.items[6][x][y] = self.controller_img.al_image_layer.items[6][x][y].sum_color(diffuse_id);
        self.controller_img.al_image_layer.items[7][x][y] = self.controller_img.al_image_layer.items[7][x][y].sum_color(diffuse_id);
        self.controller_img.al_image_layer.items[8][x][y] = self.controller_img.al_image_layer.items[8][x][y].sum_color(diffuse_id);
        self.controller_img.al_image_layer.items[9][x][y] = self.controller_img.al_image_layer.items[9][x][y].sum_color(diffuse_id);
        self.controller_img.al_image_layer.items[10][x][y] = self.controller_img.al_image_layer.items[10][x][y].sum_color(diffuse_id);
    }
}

test "render" {
    // const render_option = RenderOption{
    //     .width = 3,
    //     .height = 1,
    // };
    // const render_option = RenderOption{
    //     .width = 1920,
    //     .height = 1080,
    // };
    const render_option = RenderOption{
        .width = 3840,
        .height = 2160,
    };
    const render_destination = RenderDestination{
        .out_directory = "test_render",
        .out_img_name = "render",
    };
    var renderer = try Renderer.init(render_option);
    // renderer.render(render_destination);
    // std.debug.print("\n{d}", .{renderer.controller_img.img[0][0].aov[0].b});
    try renderer.controller_img.write_ppm(
        render_destination.out_directory,
        render_destination.out_img_name,
    );

    renderer.deinit();
}
