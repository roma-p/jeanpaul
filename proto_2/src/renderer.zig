const std = @import("std");
const gpa = std.heap.page_allocator;

const Thread = std.Thread;
const Mutex = Thread.Mutex;
const spawn = Thread.spawn;
const SpawnConfig = Thread.SpawnConfig;

const zig_utils = @import("zig_utils.zig");
const handles = @import("handle.zig");
const constants = @import("constants.zig");

const maths_vec = @import("maths_vec.zig");
const maths_mat = @import("maths_mat.zig");
const maths_tmat = @import("maths_tmat.zig");

const ControllereScene = @import("controller_scene.zig");
const ControllereObject = @import("controller_object.zig");
const ControllerImg = @import("controller_img.zig");

const jp_color = @import("jp_color.zig");

const Renderer = @This();

controller_scene: *ControllereScene,
controller_img: ControllerImg,

render_shared_data: RenderingSharedData,

pub fn init(controller_scene: *ControllereScene) Renderer {
    return .{
        .controller_scene = controller_scene,
        .controller_img = ControllerImg.init(
            controller_scene.render_settings.width,
            controller_scene.render_settings.height,
        ),
        .render_shared_data = undefined, // defined at "render"
    };
    // missing: add aov. aov model?
}

pub fn deinit(self: *Renderer) void {
    self.controller_img.deinit();
}

fn prepare_controller_img(self: *Renderer) !void {
    // adding manually every AOV for now.
    // TODO: convert this to proper Handles.
    _ = try self.controller_img.register_image_layer("beauty");
    _ = try self.controller_img.register_image_layer("alpha");
    _ = try self.controller_img.register_image_layer("z");
}

const RenderingSharedData = struct {
    mutex_get_tile_to_render: Mutex,
    next_tile_to_render: ?u16,
    tile_already_rendered: u16,
    tile_number: u16,

    const Self = @This();

    pub fn init(tile_number: u16) Self {
        return .{
            .tile_number = tile_number,
            .next_tile_to_render = 0,
            .tile_already_rendered = 0,
            .mutex_get_tile_to_render = Mutex{},
        };
    }

    pub fn get_next_tile_to_render(self: *Self, is_a_tile_finished_rendering: bool) ?u16 {
        self.mutex_get_tile_to_render.lock();
        defer self.mutex_get_tile_to_render.unlock();

        var ret = self.next_tile_to_render;

        if (self.next_tile_to_render) |*v| {
            if (v.* < self.tile_number) {
                v.* += 1;
            } else {
                ret = null;
            }
        }

        if (is_a_tile_finished_rendering) {
            self.tile_already_rendered += 1;
            // TODO: print render update!!!
        }

        return ret;
    }
};

const RenderInfo = struct {
    pixsel_size: f32,
    tile_number: u16,
    tile_x_number: u16,
    tile_y_number: u16,
    focal_plane_center: maths_vec.Vec3f32,
};

// Add more things to renderinfo. Every data needed actually.
// So no need to go to rendersettings anymore (so EZ override)
fn gen_render_info(self: *Renderer, camera_handle: handles.HandleCamera) !RenderInfo {
    var controller_object = self.controller_scene.controller_object;
    const render_settings = self.controller_scene.render_settings;

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
        render_settings.tile_size,
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

    return RenderInfo{
        .pixsel_size = pixel_size,
        .tile_number = tile_x_y.x * tile_x_y.y, // TO DELETE ?
        .tile_x_number = tile_x_y.x,
        .tile_y_number = tile_x_y.y,
        .focal_plane_center = cam_focal_plane_center,
        // sample number 2^
    };
}

pub fn render(
    self: *Renderer,
    camera_handle: handles.HandleCamera,
    dir: []const u8,
    img_name: []const u8,
) !void {
    const renderer_info = try self.gen_render_info(camera_handle);
    const thread_number = constants.CORE_NUMBER;

    self.render_shared_data = RenderingSharedData.init(renderer_info.tile_number);
    try self.prepare_controller_img();

    var thread_array = std.ArrayList(std.Thread).init(gpa);
    defer thread_array.deinit();

    var i: usize = 0;
    while (i < thread_number) : (i += 1) {
        try thread_array.append(try std.Thread.spawn(
            .{},
            render_func_per_core,
            .{
                self,
                renderer_info,
            },
        ));
    }
    i = 0;
    while (i < thread_number) : (i += 1) {
        thread_array.items[i].join();
    }
    try self.controller_img.write_ppm(dir, img_name);
}

pub fn render_func_per_core(self: *Renderer, render_info: RenderInfo) void {
    var is_a_tile_finished_render = false;

    while (true) {
        const tile_to_render_idx = self.render_shared_data.get_next_tile_to_render(
            is_a_tile_finished_render,
        );
        if (tile_to_render_idx) |value| {
            const tile_bounding_rectangle = get_tile_bouding_rectangle(
                render_info.tile_x_number,
                value,
                // TODO: all below needs to be in render info.
                self.controller_scene.render_settings.tile_size, // put this in renderinfo.
                self.controller_scene.render_settings.width,
                self.controller_scene.render_settings.height,
                // render_info.tile_s,
            );
            var _x: u16 = tile_bounding_rectangle.x_min;
            var _y: u16 = undefined;

            while (_x <= tile_bounding_rectangle.x_max) : (_x += 1) {
                _y = tile_bounding_rectangle.y_min;
                while (_y <= tile_bounding_rectangle.y_max) : (_y += 1) {
                    self.controller_img.write_to_px(_x, _y, jp_color.JP_COLOR_RED);
                }
            }
            is_a_tile_finished_render = true;
        } else {
            return;
        }
    }
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

// TODO: do a "snail": first tile is at center, and spiral out of it to the boundaries of the image.
// maybe faster.
fn get_tile_bouding_rectangle(
    tile_number_x: u16,
    tile_id: u16,
    tile_size: u16,
    image_width: u16,
    image_height: u16,
    // TODO: missing image dimensions... otherwise can clip out of image!
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

test "i_renderer_init_deinit" {
    var controller_scene = ControllereScene.init();
    var renderer = Renderer.init(&controller_scene);
    try renderer.prepare_controller_img();
    renderer.deinit();
    controller_scene.deinit();
}

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
    controller_scene.render_settings.width = 1920;
    controller_scene.render_settings.height = 1080;
    controller_scene.render_settings.tile_size = 128;
    var renderer = Renderer.init(&controller_scene);
    const cam_1_handle: handles.HandleCamera = try controller_scene.controller_object.add_camera("camera1");
    _ = try renderer.gen_render_info(cam_1_handle); // TODO: test stuff here!
    try renderer.render(cam_1_handle, "tests", "test_render_image");
    renderer.deinit();
    controller_scene.deinit();
}

// TODO: render: generate a "payload request" object (with all asked aovs, bounces and sutch.
// TODO: for each trhead allocate on the heap. Index is given by the payload request.
// Then a system is able to reconstruct the final avos from the recevied payload.
