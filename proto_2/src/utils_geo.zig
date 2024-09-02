const std = @import("std");
const constants = @import("constants.zig");
const maths = @import("maths.zig");
const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");
const maths_bbox = @import("maths_bbox.zig");

const maths_ray = @import("maths_ray.zig");

const Vec3f32 = maths_vec.Vec3f32;
const TMatrix = maths_tmat.TMatrix;
const RndGen = std.rand.DefaultPrng;
const BoundingBox = maths_bbox.BoundingBox;
const Ray = maths_ray.Ray;
const Axis = maths_vec.Axis;

const EPSILON = constants.EPSILON;

pub const HitResult = struct {
    hit: u1,
    t: f32,
};

// -- NORMALS --

pub fn get_normal_on_implicit_sphere(sphere_center_pos: Vec3f32, point_pos: Vec3f32) Vec3f32 {
    return point_pos.substract_vector(sphere_center_pos).normalize();
}

pub fn get_normal_on_implicit_plane(plane_tmatrix: TMatrix, plane_normal: Vec3f32) Vec3f32 {
    return plane_tmatrix.multiply_with_vec3(plane_normal).normalize();
}

pub fn get_normal_on_skydome(point_pos: Vec3f32) Vec3f32 {
    return point_pos.substract_vector(Vec3f32.create_origin()).product(-1).normalize();
}

// -- COLLISION --

pub fn check_ray_hit_implicit_sphere(
    ray: Ray,
    sphere_position: maths_vec.Vec3f32,
    sphere_radius: f32,
) !HitResult {

    // - equation of the ray is : ray_origin + t * ray_direction = P
    //   where t is a scalar and p a Vec3f32 position on the 3d space.
    // - equation of the sphere is: (P - sphere_position) ^2 - r^2 = 0
    //   therefore we want to resolve : (ray_origin + t * ray_direction - sphere_position)^2 - r^2 = 0
    //   which is quatratic equation at^2 + bt + c = 0 where:
    //   a = ray_direction^2
    //   b = 2 * ray_direction * (ray_origin - sphere_position)
    //   c = (ray_origin - sphere_position) ^2 - r^2

    const L = ray.o.substract_vector(sphere_position);
    // from ray origin to sphere center

    const a: f32 = ray.d.product_dot(ray.d);
    const b: f32 = 2 * (ray.d.product_dot(L));
    const c: f32 = L.product_dot(L) - (sphere_radius * sphere_radius);

    const solution = try maths.solve_quadratic(a, b, c);
    const solution_number = solution.@"0";

    switch (solution_number) {
        0 => return .{ .hit = 0, .t = 0 },
        1 => {
            if (solution.@"1" < 0) {
                return .{ .hit = 0, .t = 0 };
            } else {
                return .{ .hit = 1, .t = solution.@"1" };
            }
        },
        2 => {
            // assuming smaller solution is always on field 1.
            if (solution.@"1" > 0) {
                return .{ .hit = 1, .t = solution.@"1" };
            } else if (solution.@"2" > 0) {
                return .{ .hit = 1, .t = solution.@"2" };
            } else {
                return .{ .hit = 0, .t = 0 };
            }
        },
        inline else => unreachable,
    }
}

pub fn check_ray_hit_implicit_plane(
    ray: Ray,
    plane_position: maths_vec.Vec3f32,
    plane_normal: maths_vec.Vec3f32,
) !HitResult {

    // - equation of the ray is : ray_origin + t * ray_direction = P
    //   where t is a scalar and p a Vec3f32 position on the 3d space.
    // - equation of the plane is: (P - plane_position) * plane_normal = 0
    // therefore we want to resolve:
    // (ray_origin + t * ray_direction - plane_position) * plane_normal = 0
    // t * ray_direction * plane_normal  =  - (ray_origin - plane_position) * plane_normal
    // t = ((plane_position - ray_origin) * plane_normal) / (ray_direction * plane_normal)

    // no solution if ray_direction dot plane_normal == 0 (if there are colinear, no intersection)
    // we only consider t > 0.

    const denominator = ray.d.product_dot(plane_normal);

    // TODO: use "almost equal".
    if (denominator == 0) { // absolute!
        return .{ .hit = 0, .t = 0 };
    }

    const _tmp = plane_position.substract_vector(ray.o);
    const numerator = _tmp.product_dot(plane_normal);

    const t: f32 = numerator / denominator;

    if (t <= EPSILON) return .{ .hit = 0, .t = 0 };

    return .{ .hit = 1, .t = t };
}

pub fn check_ray_hit_skydome(ray: Ray) !HitResult {
    return check_ray_hit_implicit_sphere(
        ray,
        maths_vec.Vec3f32.create_origin(),
        1000000,
    );
}

pub fn check_ray_hit_aabb(ray: Ray, bbox: BoundingBox) bool {
    var axis: Axis = undefined;

    var t_min: f32 = constants.EPSILON;
    var t_max: f32 = constants.INFINITE;

    var i: usize = 0;
    const axis_arr = [3]Axis{ Axis.x, Axis.y, Axis.z };
    while (i < 3) : (i += 1) {
        axis = axis_arr[i];

        const ray_d_at_axis = ray.d.get_by_axis(axis);
        const ray_o_at_axis = ray.o.get_by_axis(axis);

        const ray_dir_inverted = 1.0 / ray_d_at_axis;
        // const is_dir_neg: bool = ray_d_at_axis < 0;

        const bbox_min_max = bbox.get_by_axis(axis);

        const local_t_min = (bbox_min_max.min - ray_o_at_axis) * ray_dir_inverted;
        var local_t_max = (bbox_min_max.max - ray_o_at_axis) * ray_dir_inverted;

        local_t_max += constants.EPSILON;

        if (local_t_min < local_t_max) {
            if (local_t_min > t_min) t_min = local_t_min;
            if (local_t_max < t_max) t_max = local_t_max;
        } else {
            if (local_t_max > t_min) t_min = local_t_max;
            if (local_t_min < t_max) t_max = local_t_min;
        }

        if (t_max - t_min < constants.EPSILON) return false;
    }

    return true;
}

// -- MISC --

pub fn gen_vec_random_hemisphere_normalized(
    normal: Vec3f32,
    rng: *RndGen,
) Vec3f32 {
    var ret = Vec3f32{
        .x = rng.random().float(f32) * 2 - 1,
        .y = rng.random().float(f32) * 2 - 1,
        .z = rng.random().float(f32) * 2 - 1,
    };
    ret = ret.normalize();
    if (normal.product_dot(ret) < 0) {
        ret = ret.product(-1);
    }
    return ret;
}

pub fn gen_vec_random_spheric_normalized(rng: *RndGen) Vec3f32 {
    var ret = Vec3f32{
        .x = rng.random().float(f32) * 2 - 1,
        .y = rng.random().float(f32) * 2 - 1,
        .z = rng.random().float(f32) * 2 - 1,
    };
    ret = ret.normalize();
    return ret;
}

// -- BOUNDING BOX --

pub fn gen_bbox_implicit_sphere(pos: Vec3f32, radius: f32) BoundingBox {
    return BoundingBox{
        .x_min = pos.x - radius,
        .x_max = pos.x + radius,
        .y_min = pos.y - radius,
        .y_max = pos.y + radius,
        .z_min = pos.z - radius,
        .z_max = pos.z + radius,
    };
}

pub fn get_bounding_box_center(bouding_box: BoundingBox) Vec3f32 {
    return Vec3f32{
        .x = (bouding_box.x_max + bouding_box.x_min) / 2 + bouding_box.x_min,
        .y = (bouding_box.y_max + bouding_box.y_min) / 2 + bouding_box.y_min,
        .z = (bouding_box.z_max + bouding_box.z_min) / 2 + bouding_box.z_min,
    };
}

test "check_ray_hit_aabb" {
    const bbox = BoundingBox.create_square_box_at_position(
        Vec3f32.create_x(),
        3,
    );
    const ray_1 = Ray{
        .o = Vec3f32{ .x = -5, .y = 0, .z = 0 },
        .d = Vec3f32.create_x(),
    };
    const ray_2 = Ray{
        .o = Vec3f32{ .x = 5, .y = 0, .z = 0 },
        .d = Vec3f32.create_x_neg(),
    };
    const ray_3 = Ray{
        .o = Vec3f32{ .x = -5, .y = 0, .z = 0 },
        .d = Vec3f32.create_x_neg(),
    };
    const ray_4 = Ray{
        .o = Vec3f32{ .x = 0, .y = -5, .z = 0 },
        .d = Vec3f32.create_y(),
    };
    try std.testing.expectEqual(true, check_ray_hit_aabb(ray_1, bbox));
    try std.testing.expectEqual(true, check_ray_hit_aabb(ray_2, bbox));
    try std.testing.expectEqual(false, check_ray_hit_aabb(ray_3, bbox));
    try std.testing.expectEqual(true, check_ray_hit_aabb(ray_4, bbox));
}
