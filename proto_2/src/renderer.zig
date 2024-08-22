const std = @import("std");
const gpa = std.heap.page_allocator;
const RndGen = std.rand.DefaultPrng;

const Thread = std.Thread;
const Mutex = Thread.Mutex;
const SpawnConfig = Thread.SpawnConfig;

const constants = @import("constants.zig");

const definitions = @import("definitions.zig");
const AovStandardEnum = definitions.AovStandardEnum;

const utils_zig = @import("utils_zig.zig");
const utils_logging = @import("utils_logging.zig");
const utils_camera = @import("utils_camera.zig");
const utils_draw_2d = @import("utils_draw_2d.zig");
const utils_tile_rendering = @import("utils_tile_rendering.zig");
const utils_materials = @import("utils_materials.zig");

const math_vec = @import("maths_vec.zig");

const data_handles = @import("data_handle.zig");
const data_color = @import("data_color.zig");
const data_render_info = @import("data_render_info.zig");
const data_render_settings = @import("data_render_settings.zig");
const data_pixel_payload = @import("data_pixel_payload.zig");

const ControllereScene = @import("controller_scene.zig");
const ControllereObject = @import("controller_object.zig");
const ControllerAov = @import("controller_aov.zig");
const ControllerImg = @import("controller_img.zig");

const Renderer = @This();

const RenderInfo = data_render_info.RenderInfo;
const PixelPayload = data_pixel_payload.PixelPayload;
const Vec3f32 = math_vec.Vec3f32;

controller_scene: *ControllereScene,
controller_img: ControllerImg,

aov_to_image_layer: std.AutoHashMap(AovStandardEnum, usize),

render_info: RenderInfo,
render_shared_data: RenderDataShared,

array_thread: std.ArrayList(Thread),
array_render_data_per_thread: std.ArrayList(RenderDataPerThread),

const AOV_NOT_CLAMP = [_]AovStandardEnum{AovStandardEnum.Depth};

pub fn init(controller_scene: *ControllereScene) Renderer {
    return .{
        .controller_scene = controller_scene,
        .controller_img = ControllerImg.init(
            controller_scene.render_settings.width,
            controller_scene.render_settings.height,
        ),
        .render_shared_data = undefined, // defined at "render"
        .render_info = undefined, // defined at "render"
        .aov_to_image_layer = std.AutoHashMap(AovStandardEnum, usize).init(gpa),
        .array_render_data_per_thread = std.ArrayList(RenderDataPerThread).init(gpa),
        .array_thread = std.ArrayList(Thread).init(gpa),
    };
    // TODO: missing: add aov. aov model?
}

pub fn deinit(self: *Renderer) void {
    self.controller_img.deinit();
    self.aov_to_image_layer.deinit();
    self.array_render_data_per_thread.deinit();
    self.array_thread.deinit();
}

const RenderDataPerThread = struct {
    rnd: RndGen,
    pixel_payload: PixelPayload,
};

const RenderDataShared = struct {
    mutex: Mutex,

    pixel_done_nb: u32,
    pixel_total_nb: u32,
    last_percent_display: u16,
    last_percent_display_time: i64,
    data_per_render_type: DataPerRenderType,

    const DELAY_BETWEEN_PERCENT_DISPLAY_S = 2;

    const DataPerRenderType = union(data_render_settings.RenderType) {
        Pixel: struct {},
        Scanline: struct {},
        Tile: struct {
            next_tile_to_render: ?u16,
            tile_already_rendered: u16,
            tile_number: u16,
        },
        SingleThread: struct {},
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
                .Tile => .{
                    .Tile = .{
                        .next_tile_to_render = 0,
                        .tile_already_rendered = 0,
                        .tile_number = render_info.data_per_render_type.Tile.tile_number,
                    },
                },
                .Scanline => unreachable,
                .Pixel => unreachable,
                .SingleThread => .{ .SingleThread = .{} },
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

// -- Render -----------------------------------------------------------------

pub fn render(
    self: *Renderer,
    camera_handle: data_handles.HandleCamera,
    dir: []const u8,
    img_name: []const u8,
) !void {
    const thread_nbr = constants.CORE_NUMBER;

    try self.prepare_render(camera_handle, thread_nbr);
    defer self.dispose_render();

    const time_start = std.time.timestamp();

    switch (self.render_info.render_type) {
        data_render_settings.RenderType.Tile => try render_tile(self),
        data_render_settings.RenderType.SingleThread => try render_singlethread(self),
        data_render_settings.RenderType.Scanline => unreachable,
        data_render_settings.RenderType.Pixel => unreachable,
    }

    const time_end = std.time.timestamp();
    const time_struct = utils_logging.format_time(time_end - time_start);
    std.debug.print(
        "Rendered done in {d}h {d}m {d}s.\n",
        .{ time_struct.hour, time_struct.min, time_struct.sec },
    );

    // TODO: iterate over aov_to_image_layer. if not in "non clamp", clamp it.

    // clamping depth for ppm format. remove this when .exr supported.
    const image_layer_idx = self.aov_to_image_layer.get(AovStandardEnum.Depth);
    if (image_layer_idx != null) {
        const depth_layer = self.controller_img.array_image_layer.items[image_layer_idx.?];
        utils_draw_2d.auto_clamp_img(depth_layer);
    }

    try self.controller_img.write_ppm(dir, img_name, self.render_info.color_space);
}

fn prepare_render(self: *Renderer, camera_handle: data_handles.HandleCamera, thread_nbr: usize) !void {
    // 1. prepare control pixel_payload.check_has_aov(ler img.
    for (self.controller_scene.controller_aov.array_aov_standard.items) |aov| {
        const aov_name = @tagName(aov);
        const img_layer_idx = try self.controller_img.register_image_layer(aov_name);
        try self.aov_to_image_layer.put(aov, img_layer_idx);
    }

    // 2. initialize render info.
    self.render_info = try RenderInfo.create_from_scene(
        self.controller_scene,
        camera_handle,
        thread_nbr,
    );

    // 3. generate render info shared.
    self.render_shared_data = RenderDataShared.init(self.render_info);

    // 4. generate render info per thread.
    var i: usize = 0;
    while (i < thread_nbr) : (i += 1) {
        const render_data_per_thread = RenderDataPerThread{
            .pixel_payload = try PixelPayload.init(
                &self.controller_scene.controller_aov,
                self.render_info.samples_invert,
            ),
            .rnd = RndGen.init(i),
        };
        try self.array_render_data_per_thread.append(render_data_per_thread);
    }
}

fn dispose_render(self: *Renderer) void {
    for (self.array_render_data_per_thread.items) |*data| {
        data.pixel_payload.deinit();
    }
    self.array_render_data_per_thread.clearAndFree();
    self.render_info = undefined;
    self.render_shared_data = undefined;
    self.array_render_data_per_thread.clearAndFree();
}

// -- Render entry point -----------------------------------------------------

fn render_single_px(self: *Renderer, x: u16, y: u16, thread_idx: usize) !void {
    var pixel_payload = self.array_render_data_per_thread.items[thread_idx].pixel_payload;
    pixel_payload.reset();

    var sample_i: usize = 0;
    while (sample_i < self.render_info.samples_nbr) : (sample_i += 1) {
        try self.render_single_px_single_sample(x, y, thread_idx);
    }
    var it = pixel_payload.aov_to_color.iterator();
    while (it.next()) |item| {
        const layer_index = self.aov_to_image_layer.get(item.key_ptr.*) orelse unreachable;
        try self.controller_img.write_to_px(x, y, layer_index, item.value_ptr.*);
    }
}

fn render_single_px_single_sample(self: *Renderer, x: u16, y: u16, thread_idx: usize) !void {
    var render_data_per_thread = &self.array_render_data_per_thread.items[thread_idx];
    var pixel_payload = &render_data_per_thread.pixel_payload;

    var controller_object = &self.controller_scene.controller_object;
    var controller_material = &self.controller_scene.controller_material;

    const x_f32 = utils_zig.cast_u16_to_f32(x);
    const y_f32 = utils_zig.cast_u16_to_f32(y);

    const render_info = self.render_info;

    const calculate_time: bool = pixel_payload.check_has_aov(AovStandardEnum.DebugTimePerPixel);
    var time_start: i64 = undefined;
    if (calculate_time) time_start = std.time.timestamp();

    const ray_direction = utils_camera.get_ray_direction_from_focal_plane(
        render_info.camera_position,
        render_info.focal_plane_center,
        render_info.image_width_f32,
        render_info.image_height_f32,
        render_info.pixel_size,
        x_f32,
        y_f32,
        &render_data_per_thread.rnd,
    );

    //  -- launch primary rays -----------------------------------------------

    const hit = controller_object.send_ray_on_hittable(
        ray_direction,
        render_info.camera_position,
    );

    if (hit.does_hit == 0) return;

    pixel_payload.ray_total_length = hit.t;

    const ptr_mat = try controller_material.get_mat_pointer(hit.handle_mat);

    // -- write AOV that only depends on primary rays ------------------------

    pixel_payload.add_sample_to_aov(AovStandardEnum.Alpha, data_color.COLOR_WHITE);

    // /!\ value not clamped...
    pixel_payload.add_sample_to_aov(
        AovStandardEnum.Depth,
        data_color.Color.create_from_value_not_clamped(hit.t),
    );

    pixel_payload.add_sample_to_aov(
        AovStandardEnum.Normal,
        data_color.Color{
            .r = (hit.n.x + 1) / 2,
            .g = (hit.n.y + 1) / 2,
            .b = (hit.n.z + 1) / 2,
        },
    );

    pixel_payload.add_sample_to_aov(
        AovStandardEnum.Albedo,
        switch (ptr_mat.*) {
            .Lambertian => |v| v.base_color,
            .DiffuseLight => |v| v.color,
            .Metal => |v| v.base_color,
            else => unreachable,
        },
    );

    // -- doing the ray tracing ----------------------------------------------

    pixel_payload.set_aov_buffer_value(AovStandardEnum.Beauty, data_color.COLOR_WHITE);
    pixel_payload.set_aov_buffer_value(AovStandardEnum.Direct, data_color.COLOR_BlACK);
    pixel_payload.set_aov_buffer_value(AovStandardEnum.Indirect, data_color.COLOR_BlACK);

    try self.render_ray_trace(thread_idx, 0, hit);
    pixel_payload.dump_buffer_to_aov();

    const c = pixel_payload.get_aov_value(AovStandardEnum.Beauty).?;
    if (std.math.isNan(c.r) or std.math.isNan(c.g) or std.math.isNan(c.b)) {
        std.debug.print("\n ouiiii \n", .{});
        pixel_payload.set_aov(AovStandardEnum.DebugCheeseNan, data_color.COLOR_WHITE);
    }

    if (calculate_time) {
        const time_end = std.time.timestamp();
        const elapsed: i64 = time_end - time_start;
        const elapsed_as_f32: f32 = @as(f32, @floatFromInt(elapsed));
        pixel_payload.set_aov_buffer_value(
            AovStandardEnum.DebugTimePerPixel,
            data_color.Color.create_from_value_not_clamped(elapsed_as_f32),
        );
    }
}

fn render_ray_trace(
    self: *Renderer,
    thread_idx: usize,
    bounce_idx: u8,
    hit: ControllereObject.HitRecord,
) !void {
    var render_data_per_thread = &self.array_render_data_per_thread.items[thread_idx];
    var pixel_payload = &render_data_per_thread.pixel_payload;

    var controller_object = &self.controller_scene.controller_object;
    var controller_material = &self.controller_scene.controller_material;

    const ptr_mat = try controller_material.get_mat_pointer(hit.handle_mat);

    switch (ptr_mat.*) {
        .DiffuseLight => |m| {
            const emitted_color = utils_materials.get_emitted_color(
                m.color,
                m.intensity,
                m.exposition,
                m.decay_mode,
                pixel_payload.ray_total_length,
            );
            pixel_payload.product_aov_buffer_value(
                AovStandardEnum.Beauty,
                emitted_color,
            );
            const aov = if (bounce_idx < 2) AovStandardEnum.Direct else AovStandardEnum.Indirect;
            pixel_payload.copy_aov_buffer_value(AovStandardEnum.Beauty, aov);
            return;
        },
        inline else => {},
    }

    const scatter_result = try switch (ptr_mat.*) {
        .Lambertian => |v| utils_materials.scatter_lambertian(
            hit.p,
            hit.n,
            v.base_color,
            v.base,
            v.ambiant,
            &render_data_per_thread.rnd,
        ),
        .Metal => |v| utils_materials.scatter_metal(
            hit.p,
            hit.ray_direction,
            hit.n,
            v.base_color,
            v.base,
            v.ambiant,
            v.fuzz,
            &render_data_per_thread.rnd,
        ),
        .Phong => unreachable,
        .DiffuseLight => unreachable,
    };

    if (hit.does_hit == 0) {
        pixel_payload.product_aov_buffer_value(AovStandardEnum.Beauty, data_color.COLOR_BlACK);
        return;
    }

    pixel_payload.product_aov_buffer_value(AovStandardEnum.Beauty, scatter_result.attenuation);

    switch (hit.handle_hittable) {
        .HandleEnv => {
            pixel_payload.product_aov_buffer_value(AovStandardEnum.Beauty, data_color.COLOR_BlACK);
            return;
        },
        inline else => {},
    }

    if (bounce_idx == self.render_info.bounces) {
        pixel_payload.set_aov_buffer_value(AovStandardEnum.Beauty, data_color.COLOR_BlACK);
        return;
    }

    const new_hit = controller_object.send_ray_on_hittable(
        scatter_result.ray_direction,
        scatter_result.ray_origin,
    );

    if (new_hit.does_hit == 0) {
        pixel_payload.product_aov_buffer_value(AovStandardEnum.Beauty, data_color.COLOR_BlACK);
        return;
    }

    pixel_payload.ray_total_length += new_hit.t;

    try self.render_ray_trace(thread_idx, bounce_idx + 1, new_hit);
}

// -- Render Type : SingleThread ---------------------------------------------

fn render_singlethread(self: *Renderer) !void {
    const render_info = self.render_info;

    var _x: u16 = 0;
    var _y: u16 = undefined;

    while (_x < render_info.image_width) : (_x += 1) {
        _y = 0;
        while (_y < render_info.image_height) : (_y += 1) {
            try self.render_single_px(_x, _y, 0);
            self.render_shared_data.add_rendered_pixel_number(1);
            self.render_shared_data.update_progress();
        }
    }
}

// -- Render Type : Tile -----------------------------------------------------

pub fn render_tile(self: *Renderer) !void {
    // Maybe this directly in "render"?
    const thread_nbr = self.render_info.thread_nbr;
    var i: usize = 0;
    while (i < thread_nbr) : (i += 1) {
        try self.array_thread.append(try std.Thread.spawn(
            .{},
            render_tile_single_thread_func,
            .{ self, i },
        ));
    }
    i = 0;
    while (i < thread_nbr) : (i += 1) {
        self.array_thread.items[i].join();
    }
}

fn render_tile_single_thread_func(self: *Renderer, thread_idx: usize) !void {
    const render_info = self.render_info;
    var is_a_tile_finished_render = false;
    var pxl_rendered_nbr: u16 = 0;

    while (true) {
        const tile_to_render_idx = self.render_shared_data.get_next_tile_to_render(
            is_a_tile_finished_render,
            pxl_rendered_nbr,
        );
        if (tile_to_render_idx) |value| {
            const tile_bounding_rect = utils_tile_rendering.get_tile_bouding_rectangle_line_mode(
                render_info.data_per_render_type.Tile.tile_x_number,
                value,
                render_info.data_per_render_type.Tile.tile_size,
                render_info.image_width,
                render_info.image_height,
            );
            pxl_rendered_nbr = utils_tile_rendering.get_tile_pixel_number(tile_bounding_rect);

            var _x: u16 = tile_bounding_rect.x_min;
            var _y: u16 = undefined;

            while (_x <= tile_bounding_rect.x_max) : (_x += 1) {
                _y = tile_bounding_rect.y_min;
                while (_y <= tile_bounding_rect.y_max) : (_y += 1) {
                    try self.render_single_px(_x, _y, thread_idx);
                }
            }
            is_a_tile_finished_render = true;
        } else {
            return;
        }
    }
}
