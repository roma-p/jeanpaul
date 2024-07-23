const std = @import("std");
const gpa = std.heap.page_allocator;

const Thread = std.Thread;
const Mutex = Thread.Mutex;
const SpawnConfig = Thread.SpawnConfig;

const zig_utils = @import("zig_utils.zig");
const handles = @import("handle.zig");
const constants = @import("constants.zig");
const render_settings = @import("render_settings.zig");

const maths_vec = @import("maths_vec.zig");
const maths_mat = @import("maths_mat.zig");
const maths_tmat = @import("maths_tmat.zig");

const ControllereScene = @import("controller_scene.zig");
const ControllereObject = @import("controller_object.zig");
const ControllerAov = @import("controller_aov.zig");
const ControllerImg = @import("controller_img.zig");

const jp_color = @import("jp_color.zig");

const Renderer = @This();

controller_scene: *ControllereScene,
controller_img: ControllerImg,

render_shared_data: RenderingSharedData,
render_info: RenderInfo,
aov_to_image_layer: std.AutoHashMap(ControllerAov.AovStandard, usize),

pub fn init(controller_scene: *ControllereScene) Renderer {
    return .{
        .controller_scene = controller_scene,
        .controller_img = ControllerImg.init(
            controller_scene.render_settings.width,
            controller_scene.render_settings.height,
        ),
        .render_shared_data = undefined, // defined at "render"
        .render_info = undefined, // defined at "render"
        .aov_to_image_layer = std.AutoHashMap(ControllerAov.AovStandard, usize).init(gpa),
    };
    // missing: add aov. aov model?
}

pub fn deinit(self: *Renderer) void {
    self.controller_img.deinit();
    self.aov_to_image_layer.deinit();
}

// -- Render -----------------------------------------------------------------

pub fn render(
    self: *Renderer,
    camera_handle: handles.HandleCamera,
    dir: []const u8,
    img_name: []const u8,
) !void {
    try self.prepare_controller_img();
    const time_start = std.time.timestamp();

    self.render_info = try self.gen_render_info(camera_handle);

    switch (self.render_info.render_type) {
        render_settings.RenderType.Tile => try render_tile(
            self,
            camera_handle,
            self.render_info,
        ),
        render_settings.RenderType.Scanline => unreachable,
        render_settings.RenderType.SingleThread => unreachable,
    }

    const time_end = std.time.timestamp();
    const time_elapsed = time_end - time_start;
    const time_struct = format_time(time_elapsed);
    std.debug.print(
        "Rendered done in {d}h {d}m {d}s.\n",
        .{ time_struct.hour, time_struct.min, time_struct.sec },
    );

    try self.controller_img.write_ppm(dir, img_name);
}

// -- Render Type : Tile -----------------------------------------------------

pub fn render_tile(
    self: *Renderer,
    camera_handle: handles.HandleCamera,
    render_info: RenderInfo,
) !void {
    _ = camera_handle;
    const thread_number = constants.CORE_NUMBER;

    self.render_shared_data = RenderingSharedData.init(render_info);

    var thread_array = std.ArrayList(std.Thread).init(gpa);
    defer thread_array.deinit();

    var i: usize = 0;
    while (i < thread_number) : (i += 1) {
        try thread_array.append(try std.Thread.spawn(
            .{},
            render_tile_single_thread_func,
            .{
                self,
                render_info,
            },
        ));
    }
    i = 0;
    while (i < thread_number) : (i += 1) {
        thread_array.items[i].join();
    }
}

fn render_tile_single_thread_func(self: *Renderer, render_info: RenderInfo) !void {
    var is_a_tile_finished_render = false;
    var pxl_rendered_nbr: u16 = 0;

    var pixel_payload = try PixelPayload.init(
        &self.controller_scene.controller_aov,
        self.render_info.samples_invert,
    );
    defer pixel_payload.deinit();

    while (true) {
        const tile_to_render_idx = self.render_shared_data.get_next_tile_to_render(
            is_a_tile_finished_render,
            pxl_rendered_nbr,
        );
        if (tile_to_render_idx) |value| {
            const tile_bounding_rectangle = get_tile_bouding_rectangle(
                render_info.data_per_render_type.Tile.tile_x_number,
                value,
                render_info.data_per_render_type.Tile.tile_size,
                render_info.image_width,
                render_info.image_height,
            );
            pxl_rendered_nbr = get_tile_pixel_number(tile_bounding_rectangle);

            var _x: u16 = tile_bounding_rectangle.x_min;
            var _y: u16 = undefined;

            while (_x <= tile_bounding_rectangle.x_max) : (_x += 1) {
                _y = tile_bounding_rectangle.y_min;
                while (_y <= tile_bounding_rectangle.y_max) : (_y += 1) {
                    self.render_single_px(_x, _y, &pixel_payload);
                }
            }
            is_a_tile_finished_render = true;
        } else {
            return;
        }
    }
}

fn render_single_px(self: *Renderer, x: u16, y: u16, pixel_payload: *PixelPayload) void {
    pixel_payload.reset();
    var sample_i: usize = 0;
    while (sample_i < self.render_info.samples_nbr) : (sample_i += 1) {
        self.render_single_px_single_sample(x, y, pixel_payload);
    }
    var it = pixel_payload.aov_to_color.iterator();
    while (it.next()) |item| {
        const layer_index = self.aov_to_image_layer.get(item.key_ptr.*) orelse unreachable;
        self.controller_img.write_to_px(x, y, layer_index, item.value_ptr.*);
    }
}

fn render_single_px_single_sample(self: *Renderer, x: u16, y: u16, pixel_payload: *PixelPayload) void {
    _ = x;
    _ = y;
    _ = self;

    pixel_payload.add_sample_to_aov(ControllerAov.AovStandard.Beauty, jp_color.JP_COLOR_RED);
    pixel_payload.add_sample_to_aov(ControllerAov.AovStandard.Normal, jp_color.JP_COLOR_GREY);
}

fn calculate_tile_number(
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

fn get_tile_bouding_rectangle(
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

fn get_tile_pixel_number(bouding_rectangle: maths_mat.BoudingRectangleu16) u16 {
    const x_number = bouding_rectangle.x_max - bouding_rectangle.x_min;
    const y_number = bouding_rectangle.y_max - bouding_rectangle.y_min;
    const ret = @mulWithOverflow(x_number, y_number).@"0";
    return ret;
}

// -- Prepare ----------------------------------------------------------------

fn prepare_controller_img(self: *Renderer) !void {
    for (self.controller_scene.controller_aov.array_aov_standard.items) |aov| {
        const aov_name = @tagName(aov);
        const img_layer_idx = try self.controller_img.register_image_layer(aov_name);
        try self.aov_to_image_layer.put(aov, img_layer_idx);
    }
}

const RenderInfo = struct {
    pixel_size: f32,

    image_width: u16,
    image_height: u16,

    samples: u16,
    bounces: u16,

    render_type: render_settings.RenderType,
    focal_plane_center: maths_vec.Vec3f32,
    data_per_render_type: DataPerRenderType,

    samples_nbr: u16,
    samples_invert: f32,

    const DataPerRenderType = union(render_settings.RenderType) {
        SingleThread: struct {},
        Scanline: struct {},
        Tile: struct {
            tile_size: u16,
            tile_number: u16,
            tile_x_number: u16,
            tile_y_number: u16,
        },
    };
};

fn gen_render_info(self: *Renderer, camera_handle: handles.HandleCamera) !RenderInfo {
    var controller_object = self.controller_scene.controller_object;
    const scene_render_settings = self.controller_scene.render_settings;

    const image_width: u16 = self.controller_img.width;
    const image_height: u16 = self.controller_img.height;

    const ptr_cam_entity: *const ControllereObject.Camera = try controller_object.get_camera_pointer(camera_handle);
    const ptr_cam_tmatrix: *const maths_tmat.TMatrix = try controller_object.get_tmatrix_pointer(
        ptr_cam_entity.*.handle_tmatrix,
    );

    const focal_length: f32 = ptr_cam_entity.*.focal_length;
    const field_of_view: f32 = ptr_cam_entity.*.field_of_view;

    const tile_x_y: maths_vec.Vec2(u16) = calculate_tile_number(
        image_width,
        image_height,
        scene_render_settings.tile_size,
    );

    const cam_direction: maths_vec.Vec3f32 = get_camera_absolute_direction(
        ptr_cam_tmatrix.*,
        ControllereObject.Camera.CAMERA_DIRECTION,
    );

    const cam_focal_plane_center: maths_vec.Vec3f32 = get_camera_focal_plane_center(
        ptr_cam_tmatrix.*,
        cam_direction,
        focal_length,
    );

    const pixel_size: f32 = get_pixel_size_on_focal_plane(
        focal_length,
        field_of_view,
        image_width,
    );

    const sample_nbr = std.math.pow(u16, 2, scene_render_settings.samples);
    const sample_nbr_as_f32: f32 = @floatFromInt(sample_nbr);
    const invert_sample_nbr: f32 = 1 / sample_nbr_as_f32;

    return RenderInfo{
        .pixel_size = pixel_size,
        .image_width = image_width,
        .image_height = image_height,
        .render_type = scene_render_settings.render_type,
        .samples = scene_render_settings.samples,
        .samples_nbr = sample_nbr,
        .samples_invert = invert_sample_nbr,
        .bounces = scene_render_settings.bounces,
        .focal_plane_center = cam_focal_plane_center,
        .data_per_render_type = switch (scene_render_settings.render_type) {
            render_settings.RenderType.Tile => RenderInfo.DataPerRenderType{
                .Tile = .{
                    .tile_size = scene_render_settings.tile_size,
                    .tile_number = tile_x_y.x * tile_x_y.y,
                    .tile_x_number = tile_x_y.x,
                    .tile_y_number = tile_x_y.y,
                },
            },
            render_settings.RenderType.Scanline => unreachable,
            render_settings.RenderType.SingleThread => unreachable,
        },
    };
}

const RenderingSharedData = struct {
    mutex: Mutex,

    pixel_done_nb: u32,
    pixel_total_nb: u32,
    last_percent_display: u16,
    last_percent_display_time: i64,
    data_per_render_type: DataPerRenderType,

    const DELAY_BETWEEN_PERCENT_DISPLAY_S = 2;

    const DataPerRenderType = union(render_settings.RenderType) {
        SingleThread: struct {},
        Scanline: struct {},
        Tile: struct {
            next_tile_to_render: ?u16,
            tile_already_rendered: u16,
            tile_number: u16,
        },
    };

    const Self = @This();

    pub fn init(render_info: RenderInfo) Self {
        const px_number_ret = @mulWithOverflow(
            @as(u32, render_info.image_height),
            @as(u32, render_info.image_width),
        );
        if (px_number_ret.@"1" == 1) unreachable;

        return .{
            .mutex = Mutex{},
            .pixel_done_nb = 0,
            .last_percent_display = 0,
            .last_percent_display_time = 0,
            .pixel_total_nb = px_number_ret.@"0",
            .data_per_render_type = switch (render_info.data_per_render_type) {
                render_settings.RenderType.Tile => RenderingSharedData.DataPerRenderType{
                    .Tile = .{
                        .next_tile_to_render = 0,
                        .tile_already_rendered = 0,
                        .tile_number = render_info.data_per_render_type.Tile.tile_number,
                    },
                },
                render_settings.RenderType.Scanline => unreachable,
                render_settings.RenderType.SingleThread => unreachable,
            },
        };
    }

    pub fn add_rendered_pixel_number(self: *Self, pixel_rendered_number: u32) void {
        const px_number_ret = @addWithOverflow(self.pixel_done_nb, pixel_rendered_number);
        self.pixel_done_nb = px_number_ret.@"0";
    }

    pub fn update_progress(self: *Self) void {
        const pixel_done_nb: f64 = @floatFromInt(self.pixel_done_nb);
        const pixel_total_nb: f64 = @floatFromInt(self.pixel_total_nb);
        const current_percent_done_f64: f64 = @round((pixel_done_nb / pixel_total_nb) * 10) * 10;
        const current_percent_done: u16 = @intFromFloat(current_percent_done_f64);
        if (current_percent_done <= self.last_percent_display) return;

        const now = std.time.timestamp();
        const before = self.last_percent_display_time;
        if (before == 0 or (now - before) > DELAY_BETWEEN_PERCENT_DISPLAY_S or current_percent_done_f64 == 100) {
            self.last_percent_display = current_percent_done;
            self.last_percent_display_time = now;
            log_progress(current_percent_done);
        }
    }

    pub fn get_next_tile_to_render(
        self: *Self,
        is_a_tile_finished_rendering: bool,
        pxl_rendered_nbr: u16,
    ) ?u16 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const render_tile_data = switch (self.data_per_render_type) {
            render_settings.RenderType.Tile => &self.data_per_render_type.Tile,
            else => unreachable,
        };

        var ret = render_tile_data.*.next_tile_to_render;

        if (render_tile_data.*.next_tile_to_render) |*v| {
            if (v.* < render_tile_data.*.tile_number) {
                v.* += 1;
            } else {
                ret = null;
            }
        }

        if (is_a_tile_finished_rendering) {
            render_tile_data.*.tile_already_rendered += 1;
            self.add_rendered_pixel_number(pxl_rendered_nbr);
            self.update_progress();
        }
        return ret;
    }
};

const PixelPayload = struct {
    aov_to_color: std.AutoHashMap(ControllerAov.AovStandard, jp_color.JpColor),
    sample_nbr_invert: f32,

    const Self = @This();

    pub fn init(controller_aov: *ControllerAov, sample_nbr_invert: f32) !Self {
        var ret = .{
            .aov_to_color = std.AutoHashMap(ControllerAov.AovStandard, jp_color.JpColor).init(gpa),
            .sample_nbr_invert = sample_nbr_invert,
        };
        for (controller_aov.array_aov_standard.items) |aov| {
            try ret.aov_to_color.put(aov, jp_color.JP_COLOR_BlACK);
        }
        return ret;
    }

    pub fn deinit(self: *Self) void {
        self.aov_to_color.deinit();
    }

    pub fn reset(self: Self) void {
        var it = self.aov_to_color.iterator();
        while (it.next()) |item| {
            item.value_ptr.* = jp_color.JP_COLOR_BlACK;
        }
    }

    pub fn add_sample_to_aov(
        self: *Self,
        aov_standard: ControllerAov.AovStandard,
        value: jp_color.JpColor,
    ) void {
        const aov_ptr = self.aov_to_color.getPtr(aov_standard); // TODO: check for key existence....
        const sampled_value = value.multiply(self.sample_nbr_invert);
        aov_ptr.?.* = aov_ptr.?.sum_color(sampled_value);
    }
};

fn get_camera_absolute_direction(
    tmatrix: maths_tmat.TMatrix,
    relative_direction: maths_vec.Vec3f32,
) maths_vec.Vec3f32 {
    const tmp: maths_vec.Vec3f32 = tmatrix.multiply_with_vec3(relative_direction);
    return tmp.normalize();
}

fn get_camera_focal_plane_center(
    tmatrix: maths_tmat.TMatrix,
    absolute_direction: maths_vec.Vec3f32,
    focal_length: f32,
) maths_vec.Vec3f32 {
    const weighted_direction = absolute_direction.product_scalar(focal_length);
    const camera_position = tmatrix.get_position();
    return camera_position.sum_vector(weighted_direction);
}

fn get_pixel_size_on_focal_plane(
    focal_length: f32,
    field_of_view: f32,
    img_width: u16,
) f32 {
    const half_fov: f32 = field_of_view / 2;
    const half_fov_radiant: f32 = half_fov * (std.math.pi / 180.0);
    const focal_plane_width: f32 = (@tan(half_fov_radiant) * focal_length) * 2;
    const img_width_as_f32 = zig_utils.cast_u16_to_f32(img_width);
    return focal_plane_width / img_width_as_f32;
}

// -- Utils ------------------------------------------------------------------

fn log_progress(progress_percent: u16) void {
    var progress = [10]u8{ '.', '.', '.', '.', '.', '.', '.', '.', '.', '.' };
    const done: u16 = @min(progress_percent / 10, 10);

    for (0..done) |i| {
        progress[i] = ':';
    }
    std.debug.print("Render progression : [{s}] {d}%\n", .{ progress, progress_percent });
    // std.log.info("Render progression : [{s}] {d}%\n", .{ progress, progress_percent });
}

// fn log_render_info(render_info: RenderInfo) void {
// }

fn format_time(time_epoch: i64) struct { hour: u8, min: u8, sec: u8 } {
    if (time_epoch < 0) unreachable;
    const time_epoch_pos: u32 = @intCast(time_epoch);

    const min_total = time_epoch_pos / std.time.s_per_min;
    const sec = @rem(time_epoch_pos, 60);
    const hour = min_total / 60;
    const min = @rem(min_total, 60);

    const sec_u8: u8 = @intCast(sec);
    const min_u8: u8 = @intCast(min);
    const hour_u8: u8 = @intCast(hour);

    return .{
        .hour = hour_u8,
        .min = min_u8,
        .sec = sec_u8,
    };
}

// -- Tests ------------------------------------------------------------------

test "u_tiling" {
    const tile_info = calculate_tile_number(1920, 1080, 64);
    try std.testing.expectEqual(30, tile_info.x);
    try std.testing.expectEqual(17, tile_info.y);

    const bounding_rectangle_1 = get_tile_bouding_rectangle(
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

    const bounding_rectangle_2 = get_tile_bouding_rectangle(
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

test "i_prepare_render" {
    var controller_scene = ControllereScene.init();
    defer controller_scene.deinit();

    controller_scene.render_settings.width = 1920;
    controller_scene.render_settings.height = 1080;
    controller_scene.render_settings.tile_size = 128;
    controller_scene.render_settings.samples = 6;

    try controller_scene.controller_aov.add_aov_standard(ControllerAov.AovStandard.Beauty);
    try controller_scene.controller_aov.add_aov_standard(ControllerAov.AovStandard.Alpha);
    try controller_scene.controller_aov.add_aov_standard(ControllerAov.AovStandard.Normal);

    const cam_1_handle: handles.HandleCamera = try controller_scene.controller_object.add_camera("camera1");

    var renderer = Renderer.init(&controller_scene);
    defer renderer.deinit();

    try renderer.render(cam_1_handle, "tests", "test_render_image");
}
