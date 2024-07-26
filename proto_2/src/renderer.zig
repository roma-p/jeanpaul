const std = @import("std");
const gpa = std.heap.page_allocator;

const Thread = std.Thread;
const Mutex = Thread.Mutex;
const SpawnConfig = Thread.SpawnConfig;

const constants = @import("constants.zig");

const utils_zig = @import("utils_zig.zig");
const utils_camera = @import("utils_camera.zig");
const utils_logging = @import("utils_logging.zig");
const utils_tile_rendering = @import("utils_tile_rendering.zig");

const data_handles = @import("data_handle.zig");
const data_color = @import("data_color.zig");
const data_render_settings = @import("data_render_settings.zig");

const maths_vec = @import("maths_vec.zig");
const maths_mat = @import("maths_mat.zig");
const maths_tmat = @import("maths_tmat.zig");

const ControllereScene = @import("controller_scene.zig");
const ControllereObject = @import("controller_object.zig");
const ControllerAov = @import("controller_aov.zig");
const ControllerImg = @import("controller_img.zig");

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
    camera_handle: data_handles.HandleCamera,
    dir: []const u8,
    img_name: []const u8,
) !void {
    try self.prepare_controller_img();
    const time_start = std.time.timestamp();

    self.render_info = try self.gen_render_info(camera_handle);

    switch (self.render_info.render_type) {
        data_render_settings.RenderType.Tile => try render_tile(
            self,
            camera_handle,
            self.render_info,
        ),
        data_render_settings.RenderType.Scanline => unreachable,
        data_render_settings.RenderType.SingleThread => unreachable,
    }

    const time_end = std.time.timestamp();
    const time_elapsed = time_end - time_start;
    const time_struct = utils_logging.format_time(time_elapsed);
    std.debug.print(
        "Rendered done in {d}h {d}m {d}s.\n",
        .{ time_struct.hour, time_struct.min, time_struct.sec },
    );

    try self.controller_img.write_ppm(dir, img_name);
}

// -- Render Type : Tile -----------------------------------------------------

pub fn render_tile(
    self: *Renderer,
    camera_handle: data_handles.HandleCamera,
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
            const tile_bounding_rectangle = utils_tile_rendering.get_tile_bouding_rectangle(
                render_info.data_per_render_type.Tile.tile_x_number,
                value,
                render_info.data_per_render_type.Tile.tile_size,
                render_info.image_width,
                render_info.image_height,
            );
            pxl_rendered_nbr = utils_tile_rendering.get_tile_pixel_number(tile_bounding_rectangle);

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

    pixel_payload.add_sample_to_aov(ControllerAov.AovStandard.Beauty, data_color.COLOR_RED);
    pixel_payload.add_sample_to_aov(ControllerAov.AovStandard.Normal, data_color.COLOR_GREY);
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

    render_type: data_render_settings.RenderType,
    focal_plane_center: maths_vec.Vec3f32,
    data_per_render_type: DataPerRenderType,

    samples_nbr: u16,
    samples_invert: f32,

    const DataPerRenderType = union(data_render_settings.RenderType) {
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

fn gen_render_info(self: *Renderer, camera_handle: data_handles.HandleCamera) !RenderInfo {
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

    const tile_x_y: maths_vec.Vec2(u16) = utils_tile_rendering.calculate_tile_number(
        image_width,
        image_height,
        scene_render_settings.tile_size,
    );

    const cam_direction: maths_vec.Vec3f32 = utils_camera.get_camera_absolute_direction(
        ptr_cam_tmatrix.*,
        ControllereObject.Camera.CAMERA_DIRECTION,
    );

    const cam_focal_plane_center: maths_vec.Vec3f32 = utils_camera.get_camera_focal_plane_center(
        ptr_cam_tmatrix.*,
        cam_direction,
        focal_length,
    );

    const pixel_size: f32 = utils_camera.get_pixel_size_on_focal_plane(
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
            data_render_settings.RenderType.Tile => RenderInfo.DataPerRenderType{
                .Tile = .{
                    .tile_size = scene_render_settings.tile_size,
                    .tile_number = tile_x_y.x * tile_x_y.y,
                    .tile_x_number = tile_x_y.x,
                    .tile_y_number = tile_x_y.y,
                },
            },
            data_render_settings.RenderType.Scanline => unreachable,
            data_render_settings.RenderType.SingleThread => unreachable,
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

    const DataPerRenderType = union(data_render_settings.RenderType) {
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
                data_render_settings.RenderType.Tile => RenderingSharedData.DataPerRenderType{
                    .Tile = .{
                        .next_tile_to_render = 0,
                        .tile_already_rendered = 0,
                        .tile_number = render_info.data_per_render_type.Tile.tile_number,
                    },
                },
                data_render_settings.RenderType.Scanline => unreachable,
                data_render_settings.RenderType.SingleThread => unreachable,
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
            utils_logging.log_progress(current_percent_done);
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
            data_render_settings.RenderType.Tile => &self.data_per_render_type.Tile,
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
    aov_to_color: std.AutoHashMap(ControllerAov.AovStandard, data_color.Color),
    sample_nbr_invert: f32,

    const Self = @This();

    pub fn init(controller_aov: *ControllerAov, sample_nbr_invert: f32) !Self {
        var ret = .{
            .aov_to_color = std.AutoHashMap(ControllerAov.AovStandard, data_color.Color).init(gpa),
            .sample_nbr_invert = sample_nbr_invert,
        };
        for (controller_aov.array_aov_standard.items) |aov| {
            try ret.aov_to_color.put(aov, data_color.COLOR_BlACK);
        }
        return ret;
    }

    pub fn deinit(self: *Self) void {
        self.aov_to_color.deinit();
    }

    pub fn reset(self: Self) void {
        var it = self.aov_to_color.iterator();
        while (it.next()) |item| {
            item.value_ptr.* = data_color.COLOR_BlACK;
        }
    }

    pub fn add_sample_to_aov(
        self: *Self,
        aov_standard: ControllerAov.AovStandard,
        value: data_color.Color,
    ) void {
        const aov_ptr = self.aov_to_color.getPtr(aov_standard); // TODO: check for key existence....
        const sampled_value = value.multiply(self.sample_nbr_invert);
        aov_ptr.?.* = aov_ptr.?.sum_color(sampled_value);
    }
};

// -- Tests ------------------------------------------------------------------

test "i_prepare_render" {
    var controller_scene = ControllereScene.init();
    defer controller_scene.deinit();

    controller_scene.render_settings.width = 1920;
    controller_scene.render_settings.height = 1080;
    controller_scene.render_settings.tile_size = 128;
    controller_scene.render_settings.samples = 2;

    try controller_scene.controller_aov.add_aov_standard(ControllerAov.AovStandard.Beauty);
    try controller_scene.controller_aov.add_aov_standard(ControllerAov.AovStandard.Alpha);
    try controller_scene.controller_aov.add_aov_standard(ControllerAov.AovStandard.Normal);

    const cam_1_handle: data_handles.HandleCamera = try controller_scene.controller_object.add_camera("camera1");

    var renderer = Renderer.init(&controller_scene);
    defer renderer.deinit();

    try renderer.render(cam_1_handle, "tests", "test_render_image");
}
