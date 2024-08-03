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
