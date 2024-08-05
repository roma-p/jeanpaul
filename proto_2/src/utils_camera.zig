const std = @import("std");
const maths_tmat = @import("maths_tmat.zig");
const maths_vec = @import("maths_vec.zig");
const utils_zig = @import("utils_zig.zig");

pub fn get_camera_absolute_direction(
    tmatrix: maths_tmat.TMatrix,
    relative_direction: maths_vec.Vec3f32,
) maths_vec.Vec3f32 {
    const tmp: maths_vec.Vec3f32 = tmatrix.multiply_with_vec3(relative_direction);
    return tmp.normalize();
}

pub fn get_camera_focal_plane_center(
    tmatrix: maths_tmat.TMatrix,
    absolute_direction: maths_vec.Vec3f32,
    focal_length: f32,
) maths_vec.Vec3f32 {
    const weighted_direction = absolute_direction.product(focal_length);
    const camera_position = tmatrix.get_position();
    return camera_position.sum_vector(weighted_direction);
}

pub fn get_pixel_size_on_focal_plane(
    focal_length: f32,
    field_of_view: f32,
    img_width: u16,
) f32 {
    const half_fov: f32 = field_of_view / 2;
    const half_fov_radiant: f32 = half_fov * (std.math.pi / 180.0);
    const focal_plane_width: f32 = (@tan(half_fov_radiant) * focal_length) * 2;
    const img_width_as_f32 = utils_zig.cast_u16_to_f32(img_width);
    return focal_plane_width / img_width_as_f32;
}

pub fn get_ray_direction_from_focal_plane(
    camera_position: maths_vec.Vec3f32,
    focal_plane_center: maths_vec.Vec3f32,
    screen_width: f32,
    screen_height: f32,
    pixel_size: f32,
    x: f32,
    y: f32,
    rnd: *std.rand.DefaultPrng,
) maths_vec.Vec3f32 {
    const rand_1 = (rnd.random().float(f32) * pixel_size) - pixel_size / 2;
    const rand_2 = (rnd.random().float(f32) * pixel_size) - pixel_size / 2;

    // + pixel_size / 2 -> hitting the middle of the pixel
    const focal_plane_center_to_px_position = maths_vec.Vec3f32{
        .x = (x - screen_width / 2) * pixel_size + pixel_size / 2 + rand_1,
        .y = (y - screen_height / 2) * pixel_size + pixel_size / 2 + rand_2,
        .z = 0,
    };

    const screen_px_focal_plane_position = focal_plane_center.sum_vector(focal_plane_center_to_px_position);
    const ray_direction = screen_px_focal_plane_position.substract_vector(camera_position);
    return ray_direction;
}
