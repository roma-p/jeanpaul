const std = @import("std");
const allocator = std.heap.page_allocator;
const stdout = std.io.getStdOut().writer();

const types = @import("types.zig");
const jp_img = @import("jp_img.zig");
const jp_ray = @import("jp_ray.zig");
const jp_scene = @import("jp_scene.zig");
const jp_object = @import("jp_object.zig");

pub fn get_ray_direction_from_focal_plane(
    camera: *const jp_object.JpObject,
    focal_plane_center: types.Vec3f32,
    screen_width: f32,
    screen_height: f32,
    pixel_size: f32,
    x: f32,
    y: f32,
) types.Vec3f32 {
    // + pixel_size / 2 -> hitting the middle of the pixel
    const focal_plane_center_to_px_position = types.Vec3f32{
        .x = (x - screen_width / 2) * pixel_size + pixel_size / 2,
        .y = (y - screen_height / 2) * pixel_size + pixel_size / 2,
        .z = 0,
    };
    const screen_px_focal_plane_position = focal_plane_center.sum_vector(
        &focal_plane_center_to_px_position,
    );
    const ray_direction = screen_px_focal_plane_position.substract_vector(
        &camera.tmatrix.get_position(),
    );
    return ray_direction;
}

pub fn get_focal_plane_center(camera: *const jp_object.JpObject) types.Vec3f32 {
    // camera.pos + camera.direction * focal_length
    var weighted_direction = camera.shape.Camera.direction.product_scalar(
        camera.shape.Camera.focal_length,
    );
    var position = camera.tmatrix.get_position();
    return position.sum_vector(&weighted_direction);
}

pub fn render(
    img: *jp_img.JpImg,
    camera: *jp_object.JpObject,
    scene: *jp_scene.JpScene,
) !void {
    const focal_center = get_focal_plane_center(camera);
    const camera_position = camera.tmatrix.get_position();

    const img_width: f32 = types.cast_u16_to_f32(img.*.width);
    const img_height: f32 = types.cast_u16_to_f32(img.*.height);

    const pixel_size = try get_pixel_size(
        camera.shape.Camera.focal_length,
        camera.shape.Camera.field_of_view,
        img_width,
    );

    var _x: u16 = 0;
    var _y: u16 = undefined;

    var _ray_direction: types.Vec3f32 = undefined;

    var _intersect_one_obj: bool = undefined;
    var _intersect_position: types.Vec3f32 = undefined;
    var _intersect_object: jp_object.JpObject = undefined;

    while (_x < img.width) : (_x += 1) {
        _y = img.height - 1;
        while (_y != 0) : (_y -= 1) {
            _ray_direction = get_ray_direction_from_focal_plane(
                camera,
                focal_center,
                img_width,
                img_height,
                pixel_size,
                types.cast_u16_to_f32(_x),
                types.cast_u16_to_f32(_y),
            );
            _intersect_one_obj = try jp_ray.shot_ray(
                camera_position,
                &_intersect_object,
                &_intersect_position,
                _ray_direction,
                scene,
            );
            if (_intersect_one_obj == false) {
                continue;
            }
            try jp_img.image_draw_at_px(
                img,
                _x,
                _y,
                _intersect_object.material.mat.Lambert.diffuse,
            );
        }
    }
}

pub fn get_pixel_size(
    focal_length: f32,
    field_of_view: f32,
    img_width: f32,
) !f32 {
    const half_fov: f32 = field_of_view / 2;
    const half_fov_radiant: f32 = half_fov * (std.math.pi / 180.0);
    const focal_plane_width: f32 = (@tan(half_fov_radiant) * focal_length) * 2;
    const pixel_size: f32 = focal_plane_width / img_width;
    return pixel_size;
}
