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
const maths_ray = @import("maths_ray.zig");

const data_handles = @import("data_handle.zig");
const data_color = @import("data_color.zig");
const data_render_info = @import("data_render_info.zig");
const data_render_settings = @import("data_render_settings.zig");

const ControllereScene = @import("controller_scene.zig");
const ControllereObject = @import("controller_object.zig");
const ControllerAov = @import("controller_aov.zig");
const ControllerImg = @import("controller_img.zig");

const RendererRayCollision = @import("renderer_ray_collision.zig");
const renderer_shared_data = @import("renderer_shared_data.zig");
const renderer_thread_unique_data = @import("renderer_thread_unique_data.zig");

const Renderer = @This();

const RenderInfo = data_render_info.RenderInfo;
const RenderDataShared = renderer_shared_data.RenderDataShared;
const RenderDataPerThread = renderer_thread_unique_data.RenderDataPerThread;
const Vec3f32 = math_vec.Vec3f32;
const Ray = maths_ray.Ray;
const ScatterResult = utils_materials.ScatterResult;

const renderer_scratch_buffer = @import("renderer_scratch_buffer.zig");
const ContributionEnum = renderer_scratch_buffer.ContributionEnum;

renderer_ray_collision: RendererRayCollision,

controller_scene: *ControllereScene,
controller_img: ControllerImg,

aov_to_image_layer: std.AutoHashMap(AovStandardEnum, usize),

render_info: RenderInfo,
render_shared_data: RenderDataShared,

array_thread: std.ArrayList(Thread),
array_render_data_per_thread: std.ArrayList(RenderDataPerThread),

const AOV_NOT_CLAMP = [_]AovStandardEnum{AovStandardEnum.Depth};

const RayType = enum { Specular, Diffuse, Transmission };

pub fn init(controller_scene: *ControllereScene) !Renderer {
    return .{
        .renderer_ray_collision = try RendererRayCollision.init(
            &controller_scene.controller_object,
            controller_scene.render_settings.collision_acceleration,
        ),
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

    try self.renderer_ray_collision.init_collision_accelerator();

    const time_start = std.time.timestamp();

    switch (self.render_info.render_type) {
        data_render_settings.RenderType.Tile => try render_tile(self),
        data_render_settings.RenderType.SingleThread => try render_singlethread(self),
        data_render_settings.RenderType.Scanline => unreachable,
        data_render_settings.RenderType.Pixel => try render_pixel(self),
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
    // 1. prepare control scratch_buffer.check_has_aov(ler img.
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
        const render_data_per_thread = try RenderDataPerThread.init(
            &self.controller_scene.controller_aov,
            self.render_info.samples_invert,
            self.render_info.samples_antialasing_invert,
            i,
        );

        try self.array_render_data_per_thread.append(render_data_per_thread);
    }
}

fn dispose_render(self: *Renderer) void {
    for (self.array_render_data_per_thread.items) |*data| {
        data.scratch_buffer.deinit();
    }
    self.array_render_data_per_thread.clearAndFree();
    self.render_info = undefined;
    self.render_shared_data = undefined;
    self.array_render_data_per_thread.clearAndFree();
}

// -- Render entry point -----------------------------------------------------

fn render_px(self: *Renderer, x: u16, y: u16, thread_idx: usize) !void {
    var scratch_buffer = &self.array_render_data_per_thread.items[thread_idx].scratch_buffer;
    scratch_buffer.reset();

    // time per pixel AOV handling.
    const is_time_to_count: bool = scratch_buffer.check_has_aov(AovStandardEnum.DebugTimePerPixel);
    var time_start: i64 = undefined;
    if (is_time_to_count) time_start = std.time.timestamp();

    // rendering once per AA sample.
    var sample_i: usize = 0;
    while (sample_i < self.render_info.samples_antialasing_nbr) : (sample_i += 1) {
        try self.render_px_aa_sample(x, y, thread_idx);
    }

    // writing aov from contributions data.
    scratch_buffer.dump_contributions_to_aovs();
    var it = scratch_buffer.aov_to_color.iterator();
    while (it.next()) |item| {
        const layer_index = self.aov_to_image_layer.get(item.key_ptr.*) orelse unreachable;
        try self.controller_img.write_to_px(x, y, layer_index, item.value_ptr.*);
    }

    // time per pixel AOV handling.
    if (is_time_to_count) {
        const time_end = std.time.timestamp();
        const elapsed: i64 = time_end - time_start;
        const elapsed_as_f32: f32 = @as(f32, @floatFromInt(elapsed));
        scratch_buffer.set_aov(
            AovStandardEnum.DebugTimePerPixel,
            data_color.Color.create_from_value_not_clamped(elapsed_as_f32),
        );
    }
}

fn render_px_aa_sample(self: *Renderer, x: u16, y: u16, thread_idx: usize) !void {
    var render_data_per_thread = &self.array_render_data_per_thread.items[thread_idx];
    var scratch_buffer = &render_data_per_thread.scratch_buffer;
    var controller_material = &self.controller_scene.controller_material;

    const x_f32 = utils_zig.cast_u16_to_f32(x);
    const y_f32 = utils_zig.cast_u16_to_f32(y);

    const render_info = self.render_info;

    //  -- launch primary rays
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
    const hit = self.renderer_ray_collision.send_ray_on_hittable(
        Ray{ .o = render_info.camera_position, .d = ray_direction },
    );

    if (hit.does_hit == 0) return;

    scratch_buffer.ray_total_length = hit.t;
    const ptr_mat = try controller_material.get_mat_pointer(hit.handle_mat);

    // -- write AOV that only depends on primary rays

    scratch_buffer.add_aa_sample_to_aov(AovStandardEnum.Alpha, data_color.COLOR_WHITE);

    scratch_buffer.add_aa_sample_to_aov(
        AovStandardEnum.Normal,
        data_color.Color{
            .r = (hit.n.x + 1) / 2,
            .g = (hit.n.y + 1) / 2,
            .b = (hit.n.z + 1) / 2,
        },
    );

    scratch_buffer.add_aa_sample_to_aov(
        AovStandardEnum.Albedo,
        switch (ptr_mat.*) {
            .Lambertian => |v| v.base_color,
            .DiffuseLight => |v| v.color,
            .Metal => |v| v.base_color,
            .Dielectric => |v| v.base_color,
            else => unreachable,
        },
    );

    // /!\ value not clamped...
    scratch_buffer.add_aa_sample_to_aov(
        AovStandardEnum.Depth,
        data_color.Color.create_from_value_not_clamped(hit.t),
    );

    // ray tracing shading point for every sample
    var sample_i: usize = 0;
    while (sample_i < self.render_info.samples_nbr) : (sample_i += 1) {
        scratch_buffer.reset_contribution_buffer();
        try self.render_px_aa_sample_sp_sample_prim_ray(thread_idx, hit);
    }
}

fn render_px_aa_sample_sp_sample_prim_ray(
    self: *Renderer,
    thread_idx: usize,
    hit: RendererRayCollision.HitRecord,
) !void {
    // -- scattering shading point. --
    var render_data_per_thread = &self.array_render_data_per_thread.items[thread_idx];
    var scratch_buffer = &render_data_per_thread.scratch_buffer;
    const scatter_result = try self.scatter(
        hit.p,
        hit.ray_direction,
        hit.n,
        &render_data_per_thread.rnd,
        hit.handle_mat,
        scratch_buffer.ray_total_length,
        hit.face_side,
    );

    // -- handling emission / lights --
    if (scatter_result.is_scatterred == 0 and scatter_result.emission != null) {
        const emission = scatter_result.emission.?;
        scratch_buffer.add_to_contribution_buffer(emission);
        scratch_buffer.dump_contribution_buffer(ContributionEnum.Emission);
        return;
    }

    // -- if nothing was hit, blacking out contribution.
    if (hit.does_hit == 0) {
        return;
    }

    //  -- adding the contribution.
    const attenuation = scatter_result.attenuation;

    // -- if hit skydome, ending raytracing.
    switch (hit.handle_hittable) {
        .HandleEnv => return,
        inline else => {},
    }

    // -- propagating rays
    scratch_buffer.add_to_contribution_buffer(attenuation);

    // --- * diffuse
    if (scatter_result.ray_diffuse != null) {
        const new_hit = self.renderer_ray_collision.send_ray_on_hittable(scatter_result.ray_diffuse.?);
        scratch_buffer.ray_total_length += new_hit.t; // TODO not correct...
        if (new_hit.does_hit == 1) {
            try self.render_px_aa_sample_sp_sample_sec_ray(thread_idx, 1, new_hit, RayType.Diffuse);
        }
    }

    scratch_buffer.reset_contribution_buffer();
    scratch_buffer.add_to_contribution_buffer(attenuation);

    // --- * specular
    if (scatter_result.ray_specular != null) {
        const new_hit = self.renderer_ray_collision.send_ray_on_hittable(scatter_result.ray_specular.?);
        scratch_buffer.ray_total_length += new_hit.t; // TODO not correct...
        if (new_hit.does_hit == 1) {
            try self.render_px_aa_sample_sp_sample_sec_ray(thread_idx, 1, new_hit, RayType.Specular);
        }
    }

    scratch_buffer.reset_contribution_buffer();
    scratch_buffer.add_to_contribution_buffer(attenuation);

    // --- * transmission
    if (scatter_result.ray_transmission != null) {
        const new_hit = self.renderer_ray_collision.send_ray_on_hittable(scatter_result.ray_transmission.?);
        scratch_buffer.ray_total_length += new_hit.t; // TODO not correct...
        if (new_hit.does_hit == 1) {
            try self.render_px_aa_sample_sp_sample_sec_ray(thread_idx, 1, new_hit, RayType.Transmission);
        }
    }
}

fn render_px_aa_sample_sp_sample_sec_ray(
    self: *Renderer,
    thread_idx: usize,
    bounce_idx: u8,
    hit: RendererRayCollision.HitRecord,
    ray_type: RayType,
) !void {
    // -- scattering shading point. --
    var render_data_per_thread = &self.array_render_data_per_thread.items[thread_idx];
    var scratch_buffer = &render_data_per_thread.scratch_buffer;
    const scatter_result = try self.scatter(
        hit.p,
        hit.ray_direction,
        hit.n,
        &render_data_per_thread.rnd,
        hit.handle_mat,
        scratch_buffer.ray_total_length,
        hit.face_side,
    );

    // -- handling emission / lights --
    if (scatter_result.is_scatterred == 0 and scatter_result.emission != null) {

        // -- determining which contribution we are working on.
        const is_direct: bool = bounce_idx < 2;
        const contribution = switch (ray_type) {
            .Specular => if (is_direct) ContributionEnum.SpecularDirect else ContributionEnum.SpecularIndirect,
            .Diffuse => if (is_direct) ContributionEnum.DiffuseDirect else ContributionEnum.DiffuseIndirect,
            .Transmission => ContributionEnum.Transmission,
        };

        const emission = scatter_result.emission.?;
        scratch_buffer.add_to_contribution_buffer(emission);
        scratch_buffer.dump_contribution_buffer(contribution);
        return;
    }

    // -- if nothing was hit, blacking out contribution.
    if (hit.does_hit == 0) {
        scratch_buffer.reset_contribution_buffer();
        return;
    }

    //  -- adding the contribution.
    scratch_buffer.add_to_contribution_buffer(scatter_result.attenuation);

    // -- if hit skydome, ending raytracing.
    switch (hit.handle_hittable) {
        .HandleEnv => return,
        inline else => {},
    }

    // -- if bounce limit reached, returning.
    if (bounce_idx == self.render_info.bounces) {
        scratch_buffer.reset_contribution_buffer();
        return;
    }

    // -- propagating rays

    // --- * diffuse
    if (scatter_result.ray_diffuse != null) {
        const new_hit = self.renderer_ray_collision.send_ray_on_hittable(scatter_result.ray_diffuse.?);
        scratch_buffer.ray_total_length += new_hit.t; // TODO not correct...
        if (new_hit.does_hit == 1) {
            try self.render_px_aa_sample_sp_sample_sec_ray(thread_idx, bounce_idx + 1, new_hit, ray_type);
        }
    }

    // --- * specular
    if (scatter_result.ray_specular != null) {
        const new_hit = self.renderer_ray_collision.send_ray_on_hittable(scatter_result.ray_specular.?);
        scratch_buffer.ray_total_length += new_hit.t; // TODO not correct...
        if (new_hit.does_hit == 1) {
            try self.render_px_aa_sample_sp_sample_sec_ray(thread_idx, bounce_idx + 1, new_hit, ray_type);
        }
    }

    // --- * transmission
    if (scatter_result.ray_transmission != null) {
        const new_hit = self.renderer_ray_collision.send_ray_on_hittable(scatter_result.ray_transmission.?);
        scratch_buffer.ray_total_length += new_hit.t; // TODO not correct...
        if (new_hit.does_hit == 1) {
            try self.render_px_aa_sample_sp_sample_sec_ray(thread_idx, 1, new_hit, ray_type);
        }
    }
}

pub fn scatter(
    self: *Renderer,
    p: Vec3f32,
    ray_direction: Vec3f32,
    normal: Vec3f32,
    rng: *RndGen,
    handle_mat: data_handles.HandleMaterial,
    ray_total_length: f32,
    face_side: u1,
) !ScatterResult {
    const controller_material = &self.controller_scene.controller_material;
    const ptr_mat = try controller_material.get_mat_pointer(handle_mat);

    return switch (ptr_mat.*) {
        .DiffuseLight => |m| utils_materials.get_emitted_color(
            m.color,
            m.intensity,
            m.exposition,
            m.decay_mode,
            ray_total_length,
        ),
        .Lambertian => |v| utils_materials.scatter_lambertian(
            p,
            normal,
            v.base_color,
            v.base,
            v.ambiant,
            rng,
        ),
        .Metal => |v| utils_materials.scatter_metal(
            p,
            ray_direction,
            normal,
            v.base_color,
            v.base,
            v.ambiant,
            v.fuzz,
            rng,
        ),
        .Dielectric => |v| utils_materials.scatter_dieletric(
            p,
            ray_direction,
            normal,
            v.base_color,
            if (face_side == 1) 1 / v.ior else v.ior,
            rng,
        ),
        .Phong => unreachable,
    };
}

// -- Render Type : SingleThread ---------------------------------------------

fn render_singlethread(self: *Renderer) !void {
    const render_info = self.render_info;

    var _x: u16 = 0;
    var _y: u16 = undefined;

    while (_x < render_info.image_width) : (_x += 1) {
        _y = 0;
        while (_y < render_info.image_height) : (_y += 1) {
            try self.render_px(_x, _y, 0);
            // TODO: do this less often...
            self.render_shared_data.add_rendered_pixel_number(1);
        }
        self.render_shared_data.update_progress();
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
                    try self.render_px(_x, _y, thread_idx);
                }
            }
            is_a_tile_finished_render = true;
        } else {
            return;
        }
    }
}

// -- Render Type : Pixel ----------------------------------------------------

fn render_pixel(self: *Renderer) !void {
    const render_info = self.render_info;

    const px_x = render_info.data_per_render_type.Pixel.render_single_px_x;
    const px_y = render_info.data_per_render_type.Pixel.render_single_px_y;

    if (px_x > render_info.image_width or px_y > render_info.image_height) {
        std.debug.print(
            "pixel asked ({d},{d}) outside of image ({d}x{d})\n",
            .{ px_x, px_y, render_info.image_width, render_info.image_height },
        );
        return;
    }

    std.debug.print(
        "rendering pixel: ({d},{d}), image size : ({d}x{d})\n",
        .{ px_x, px_y, render_info.image_width, render_info.image_height },
    );
    try self.render_px(px_x, px_y, 0);
}
