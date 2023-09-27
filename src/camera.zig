const std = @import("std");
const types = @import("types.zig");
const allocator = std.heap.page_allocator;
const stdout = std.io.getStdOut().writer();
const math_utils = @import("math_utils.zig");

pub const Camera = struct {
    position: types.Vec3f32 = undefined,
    focal_length: f32 = undefined,
    direction: types.Vec3f32 = types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = 1,
    },
};

fn get_ray_direction(
    camera: *const Camera,
    focal_plane_center: types.Vec3f32,
    screen_width: u16,
    screen_height: u16,
    x: u16,
    y: u16,
) types.Vec3f32 {
    const half_x = screen_width / 2;
    const half_y = screen_height / 2;

    const half_x_f32 = types.cast_u16_to_f32(half_x);
    const half_y_f32 = types.cast_u16_to_f32(half_y);

    const x_f32 = types.cast_u16_to_f32(x);
    const y_f32 = types.cast_u16_to_f32(y);

    const focal_plane_center_to_px_position = types.Vec3f32{
        .x = x_f32 - half_x_f32,
        .y = y_f32 - half_y_f32,
        .z = 0,
    };
    const screen_px_focal_plane_position = focal_plane_center.sum_vector(
        &focal_plane_center_to_px_position,
    );
    const ray_direction = screen_px_focal_plane_position.substract_vector(&camera.position);
    return ray_direction;
}

fn get_focal_plane_center(camera: *const Camera) types.Vec3f32 {
    // camera.pos + camera.direction * focal_length
    const weighted_direction: types.Vec3f32 = camera.direction.product_scalar(
        camera.focal_length,
    );
    return camera.position.sum_vector(&weighted_direction);
}

fn check_ray_intersect_with_sphere(
    ray_direction: types.Vec3f32,
    ray_origin: types.Vec3f32,
    sphere_position: types.Vec3f32,
    sphere_radius: f32,
    intersect_position: *types.Vec3f32,
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
    if (t0 > t1) {
        t = t1;
    } else {
        t = t0;
    }

    intersect_position.* = ray_direction.product_scalar(t).sum_vector(&ray_origin);
    return true;
}

test "get_focal_plane_center_on_valid_case" {
    const camera = Camera{
        .position = types.Vec3f32{
            .x = 0,
            .y = 0,
            .z = -20,
        },
        .focal_length = 10,
    };
    const center = get_focal_plane_center(&camera);
    try stdout.print("{d}, {d}, {d}", .{ center.x, center.y, center.z });
    try std.testing.expectEqual(center.x, 0);
    try std.testing.expectEqual(center.y, 0);
    try std.testing.expectEqual(center.z, -10);
}

test "get_ray_direction_on_valid_case" {
    const camera = Camera{
        .position = types.Vec3f32{
            .x = 0,
            .y = 0,
            .z = -20,
        },
        .focal_length = 10,
    };
    const focal_center = get_focal_plane_center(&camera);

    var ray_direction_1 = get_ray_direction(&camera, focal_center, 30, 30, 0, 0);
    try std.testing.expectEqual(ray_direction_1.x, -15);
    try std.testing.expectEqual(ray_direction_1.y, -15);
    try std.testing.expectEqual(ray_direction_1.z, 10);

    var ray_direction_2 = get_ray_direction(&camera, focal_center, 30, 30, 16, 20);
    try std.testing.expectEqual(ray_direction_2.x, 1);
    try std.testing.expectEqual(ray_direction_2.y, 5);
    try std.testing.expectEqual(ray_direction_2.z, 10);
}

test "check_ray_intersect_with_sphere_basic_test" {
    const camera = Camera{
        .position = types.Vec3f32{
            .x = 0,
            .y = 0,
            .z = -20,
        },
        .focal_length = 10,
    };

    const focal_center = get_focal_plane_center(&camera);
    var sphere_position = types.Vec3f32{ .x = 0, .y = 0, .z = 0 };
    var radius: f32 = 10;

    var intersect_position: types.Vec3f32 = undefined;

    var ray_direction_1 = get_ray_direction(&camera, focal_center, 30, 30, 0, 0);
    const intersect_1 = try check_ray_intersect_with_sphere(
        ray_direction_1,
        camera.position,
        sphere_position,
        radius,
        &intersect_position,
    );

    try std.testing.expectEqual(intersect_1, false);
    var ray_direction_2 = get_ray_direction(&camera, focal_center, 30, 30, 15, 15);
    const intersect_2 = try check_ray_intersect_with_sphere(
        ray_direction_2,
        camera.position,
        sphere_position,
        radius,
        &intersect_position,
    );
    try std.testing.expectEqual(intersect_2, true);

    var ray_direction_3 = get_ray_direction(&camera, focal_center, 30, 30, 29, 29);
    const intersect_3 = try check_ray_intersect_with_sphere(
        ray_direction_3,
        camera.position,
        sphere_position,
        radius,
        &intersect_position,
    );
    try std.testing.expectEqual(intersect_3, false);

    try std.testing.expectEqual(intersect_position.x, 0);
    try std.testing.expectEqual(intersect_position.y, 0);
    try std.testing.expectEqual(intersect_position.z, -10);
}
