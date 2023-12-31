const std = @import("std");
const types = @import("types.zig");
const math_utils = @import("math_utils.zig");
const jp_object = @import("jp_object.zig");
const jp_scene = @import("jp_scene.zig");
const allocator = std.heap.page_allocator;

// PUBLIC ====================================================================

pub const JpRayHit = struct {
    object: *jp_object.JpObject,
    position: *types.Vec3f32,
    distance: *f32,

    const Self = @This();

    pub fn new() !*Self {
        var position = try allocator.create(types.Vec3f32);
        errdefer allocator.destroy(position);
        position.* = types.Vec3f32{ .x = 0, .y = 0, .z = 0 };

        var distance = try allocator.create(f32);
        errdefer allocator.destroy(distance);
        distance.* = 0;

        var jp_ray_intersection = try allocator.create(Self);
        jp_ray_intersection.* = Self{
            .object = undefined,
            .position = position,
            .distance = distance,
        };
        return jp_ray_intersection;
    }

    pub fn delete(self: *Self) void {
        allocator.destroy(self.position);
        allocator.destroy(self.distance);
        allocator.destroy(self);
    }

    pub fn reset(self: *Self) void {
        self.object = undefined;
        self.position.x = 0;
        self.position.y = 0;
        self.position.z = 0;
        self.distance.* = 0;
    }
};

pub fn shot_ray_on_physical_objects(
    origin_position: types.Vec3f32,
    intersection: *JpRayHit,
    ray_direction: types.Vec3f32,
    scene: *jp_scene.JpScene,
) !bool {
    var _intersect_one_obj: bool = false;
    var _intersect_object: *jp_object.JpObject = undefined;
    var _t_min: f32 = 0;
    var _t_current: f32 = undefined;

    for (scene.objects.items) |obj| {
        const category = obj.get_category();
        if (category != jp_object.JpObjectCategory.Mesh and
            category != jp_object.JpObjectCategory.Implicit)
        {
            continue;
        }

        var does_intersect: bool = check_ray_hit(
            origin_position,
            ray_direction,
            obj,
            &_t_current,
        );

        if (!does_intersect) {
            continue;
        }

        _intersect_one_obj = true;
        if (_t_min == 0 or _t_current < _t_min) {
            _intersect_object = obj;
            _t_min = _t_current;
        }
    }

    if (!_intersect_one_obj) {
        return false;
    }

    intersection.*.object = _intersect_object;
    intersection.*.position.* = ray_direction.product_scalar(_t_min).sum_vector(
        &origin_position,
    );
    intersection.distance.* = _t_min;
    return true;
}

pub fn is_point_reachable_by_ray(
    origin_position: types.Vec3f32,
    target_position: types.Vec3f32,
    scene: *jp_scene.JpScene,
) !bool {
    const ray_direction = target_position.substract_vector(&origin_position);

    var _t_current: f32 = undefined;
    for (scene.objects.items) |obj| {
        const category = obj.get_category();
        if (category != jp_object.JpObjectCategory.Mesh and
            category != jp_object.JpObjectCategory.Implicit)
        {
            continue;
        }
        var does_intersect: bool = check_ray_hit(
            origin_position,
            ray_direction,
            obj,
            &_t_current,
        );
        if (!does_intersect) {
            continue;
        }

        if (_t_current < 1 and _t_current > 0) {
            return false;
        }
    }
    return true;
}

fn absFloat(x: f32) f32 {
    return if (x < 0.0) -x else x;
}

// PRIVATE ===================================================================

fn check_ray_hit(
    origin_position: types.Vec3f32,
    ray_direction: types.Vec3f32,
    obj: *jp_object.JpObject,
    t: *f32,
) bool {
    switch (obj.get_category()) {
        .Camera => return false,
        .Mesh => unreachable, // not implemented but shall be...
        // .Light => continue,
        else => {},
    }

    var does_intersect: bool = undefined;

    switch (obj.shape.*) {
        .ImplicitSphere => {
            does_intersect = try check_ray_hit_implicit_sphere(
                ray_direction,
                origin_position,
                obj.tmatrix.get_position(),
                obj.shape.ImplicitSphere.radius,
                t,
            );
        },
        .ImplicitPlane => {
            does_intersect = try check_ray_hit_implicit_plane(
                ray_direction,
                origin_position,
                obj.tmatrix.get_position(),
                jp_object.get_normal_at_position(
                    obj,
                    obj.tmatrix.get_position(),
                ),
                t,
            );
        },
        .LightOmni => {
            does_intersect = try check_ray_hit_light_omni(
                ray_direction,
                origin_position,
                obj.tmatrix.get_position(),
                t,
            );
        },
        else => {
            unreachable;
        },
    }

    if (!does_intersect) {
        return false;
    } else {
        return true;
    }
}

// HIT IMPLEMENTATION BY SHAPE TYPE ==========================================

pub fn check_ray_hit_implicit_sphere(
    ray_direction: types.Vec3f32,
    ray_origin: types.Vec3f32,
    sphere_position: types.Vec3f32,
    sphere_radius: f32,
    intersect_ray_multiplier: *f32,
) !bool {
    // - equation of the ray is : ray_origin + t * ray_direction = P
    //   where t is a scalar and p a Vec3f32 position on the 3d space.
    // - equation of the sphere is: (P - sphere_position) ^2 - r^2 = 0
    //   therefore we want to resolve : (ray_origin + t * ray_direction - sphere_position)^2 - r^2 = 0
    //   which is quatratic equation at^2 + bt + c = 0 where:
    //   a = ray_direction^2
    //   b = 2 * ray_direction * (ray_origin - sphere_position)
    //   c = (ray_origin - sphere_position) ^2 - r^2

    const L = ray_origin.substract_vector(&sphere_position); // from ray origin to sphere center

    const a: f32 = ray_direction.product_dot(&ray_direction);
    const b: f32 = 2 * (ray_direction.product_dot(&L));
    const c: f32 = L.product_dot(&L) - (sphere_radius * sphere_radius);

    var t0: f32 = undefined;
    var t1: f32 = undefined;
    const has_solution = try math_utils.solve_quadratic(a, b, c, &t0, &t1);
    if (has_solution == false) {
        return false;
    }

    var t: f32 = undefined;

    if (t0 > t1 and t1 > types.JP_EPSILON) {
        t = t1;
    } else if (t0 > types.JP_EPSILON) {
        t = t0;
    } else {
        return false;
    }
    intersect_ray_multiplier.* = t;
    return true;
}

pub fn check_ray_hit_implicit_plane(
    ray_direction: types.Vec3f32,
    ray_origin: types.Vec3f32,
    plane_position: types.Vec3f32,
    plane_normal: types.Vec3f32,
    intersect_ray_multiplier: *f32,
) !bool {
    // - equation of the ray is : ray_origin + t * ray_direction = P
    //   where t is a scalar and p a Vec3f32 position on the 3d space.
    // - equation of the plane is: (P - plane_position) * plane_normal = 0
    // therefore we want to resolve:
    // (ray_origin + t * ray_direction - plane_position) * plane_normal = 0
    // t * ray_direction * plane_normal  =  - (ray_origin - plane_position) * plane_normal
    // t = ((plane_position - ray_origin) * plane_normal) / (ray_direction * plane_normal)

    // no solution if ray_direction dot plane_normal == 0 (if there are colinear, no intersection)
    // we only consider t > 0.

    const denominator = ray_direction.product_dot(&plane_normal);
    if (denominator < types.JP_EPSILON and denominator > -types.JP_EPSILON) { // absolute!
        return false;
    }

    var _tmp = plane_position.substract_vector(&ray_origin);
    const numerator = _tmp.product_dot(&plane_normal);

    const t: f32 = numerator / denominator;

    if (t <= types.JP_EPSILON) return false;

    intersect_ray_multiplier.* = t;

    return true;
}

pub fn check_ray_hit_light_omni(
    ray_direction: types.Vec3f32,
    ray_origin: types.Vec3f32,
    light_position: types.Vec3f32,
    intersect_ray_multiplier: *f32,
) !bool {
    return check_ray_hit_point(
        ray_direction,
        ray_origin,
        light_position,
        intersect_ray_multiplier,
    );
}

pub fn check_ray_hit_point(
    ray_direction: types.Vec3f32,
    ray_origin: types.Vec3f32,
    point_position: types.Vec3f32,
    intersect_ray_multiplier: *f32,
) !bool {
    // hit to a specific point will always work,
    // so just compute the intersect_ray_multiplier.
    const L = point_position.substract_vector(&ray_origin);
    var t = L.x / ray_direction.x;
    intersect_ray_multiplier.* = t;
    return true;
}
