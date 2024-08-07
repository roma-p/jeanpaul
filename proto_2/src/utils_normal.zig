const std = @import("std");
const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");
const maths = @import("maths.zig");

const Vec3f32 = maths_vec.Vec3f32;
const TMatrix = maths_tmat.TMatrix;

// TODO: "utils_geo"

pub fn get_normal_on_implicit_sphere(sphere_center_pos: Vec3f32, point_pos: Vec3f32) Vec3f32 {
    return point_pos.substract_vector(sphere_center_pos).normalize();
}

pub fn get_normal_on_implicit_plane(plane_tmatrix: TMatrix, plane_normal: Vec3f32) Vec3f32 {
    return plane_tmatrix.multiply_with_vec3(plane_normal).normalize();
}
