const std = @import("std");

const math_vec = @import("maths_vec.zig");
const maths_mat = @import("maths_mat.zig");
const maths_tmat = @import("maths_tmat.zig");

const handles = @import("handle.zig");

const ControllereScene = @import("controller_scene.zig");
const ControllereObject = @import("controller_object.zig");

const ControllerImg = @import("controller_img.zig");

const zig_utils = @import("zig_utils.zig");

const Self = @This();

controller_scene: *ControllereScene,
controller_img: ControllerImg,

pub fn init(controller_scene: *ControllereScene) Self {
    return .{
        .controller_scene = controller_scene,
        .controller_img = ControllerImg.init(
            controller_scene.render_settings.width,
            controller_scene.render_settings.height,
        ),
    };
    // missing: add aov. aov model?
}

pub fn deinit(self: *Self) void {
    self.controller_img.deinit();
}

fn prepare_controller_img(self: *Self) !void {
    // adding manually every AOV for now.
    // TODO: convert this to proper Handles.
    _ = try self.controller_img.register_image_layer("beauty");
    _ = try self.controller_img.register_image_layer("alpha");
    _ = try self.controller_img.register_image_layer("z");
}

const RendererInfo = struct {
    pixsel_size: f32,
    tile_number: u16,
    tile_x_number: u16,
    tile_y_number: u16,
    focal_plane_center: math_vec.Vec3f32,
};

fn prepare_renderer(self: *Self, camera_handle: handles.HandleCamera) !RendererInfo {
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

    const tile_x_y: math_vec.Vec2(u16) = calculate_tile_number(
        image_width,
        image_height,
        render_settings.tile_size,
    );

    const cam_direction: math_vec.Vec3f32 = get_camera_absolute_direction(
        ptr_cam_tmatrix.*,
        ControllereObject.Camera.CAMERA_DIRECTION,
    );
    const cam_focal_plane_center: math_vec.Vec3f32 = get_camera_focal_plane_center(
        ptr_cam_tmatrix.*,
        cam_direction,
        focal_length,
    );

    const pixel_size: f32 = get_pixel_size_on_focal_plane(
        focal_length,
        field_of_view,
        image_width,
    );

    return RendererInfo{
        .pixsel_size = pixel_size,
        .tile_number = tile_x_y.x * tile_x_y.y, // TO DELETE ?
        .tile_x_number = tile_x_y.x,
        .tile_y_number = tile_x_y.y,
        .focal_plane_center = cam_focal_plane_center,
    };
}

fn calculate_tile_number(
    width: u16,
    height: u16,
    tile_size: u16,
) math_vec.Vec2(u16) {
    var x_number = width / tile_size;
    if (x_number * tile_size < width) {
        x_number += 1;
    }
    var y_number = height / tile_size;
    if (y_number * tile_size < height) {
        y_number += 1;
    }
    return math_vec.Vec2(u16){ .x = x_number, .y = y_number };
}

// TODO: do a "snail": first tile is at center, and spiral out of it to the boundaries of the image.
// maybe faster.
fn get_tile_bouding_rectangle(
    tile_number_x: u16,
    tile_id: u16,
    tile_size: u16,
) maths_mat.BoudingRectangleu16 {
    const y_index: u16 = tile_id / tile_number_x;
    const x_index: u16 = @rem(tile_id, tile_number_x);
    return maths_mat.BoudingRectangleu16{
        .x_min = x_index * tile_size,
        .x_max = x_index * tile_size + tile_size,
        .y_min = y_index * tile_size,
        .y_max = y_index * tile_size + tile_size,
    };
}

fn get_camera_absolute_direction(
    tmatrix: maths_tmat.TMatrix,
    relative_direction: math_vec.Vec3f32,
) math_vec.Vec3f32 {
    const tmp: math_vec.Vec3f32 = tmatrix.multiply_with_vec3(relative_direction);
    return tmp.normalize();
}

fn get_camera_focal_plane_center(
    tmatrix: maths_tmat.TMatrix,
    absolute_direction: math_vec.Vec3f32,
    focal_length: f32,
) math_vec.Vec3f32 {
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

test "renderer_init_deinit" {
    var controller_scene = ControllereScene.init();
    var renderer = Self.init(&controller_scene);
    try renderer.prepare_controller_img();
    renderer.deinit();
    controller_scene.deinit();
}

test "test_tiling" {
    const tile_info = calculate_tile_number(1920, 1080, 64);
    try std.testing.expectEqual(30, tile_info.x);
    try std.testing.expectEqual(17, tile_info.y);

    const bounding_rectangle_1 = get_tile_bouding_rectangle(tile_info.x, 0, 64);
    try std.testing.expectEqual(0, bounding_rectangle_1.x_min);
    try std.testing.expectEqual(64, bounding_rectangle_1.x_max);
    try std.testing.expectEqual(0, bounding_rectangle_1.y_min);
    try std.testing.expectEqual(64, bounding_rectangle_1.y_max);

    const bounding_rectangle_2 = get_tile_bouding_rectangle(tile_info.x, 52, 64);
    try std.testing.expectEqual(1408, bounding_rectangle_2.x_min);
    try std.testing.expectEqual(1472, bounding_rectangle_2.x_max);
    try std.testing.expectEqual(64, bounding_rectangle_2.y_min);
    try std.testing.expectEqual(128, bounding_rectangle_2.y_max);
}

test "test_prepare_render" {
    var controller_scene = ControllereScene.init();
    var renderer = Self.init(&controller_scene);
    const cam_1_handle: handles.HandleCamera = try controller_scene.controller_object.add_camera("camera1");
    _ = try renderer.prepare_renderer(cam_1_handle); // TODO: test stuff here!
    renderer.deinit();
    controller_scene.deinit();
}

// TODO: render: generate a "payload request" object (with all asked aovs, bounces and sutch.
// TODO: for each trhead allocate on the heap. Index is given by the payload request.
// Then a system is able to reconstruct the final avos from the recevied payload.
