const std = @import("std");
const render = @import("render.zig");
const types = @import("types.zig");
const jp_object = @import("jp_object.zig");
const jp_ray = @import("jp_ray.zig");

const JpObject = jp_object.JpObject;
const ShapeTypeId = jp_object.ShapeTypeId;

test "render.check_ray_intersect_with_sphere_basic_test" {
    var camera = try JpObject.new("camera", ShapeTypeId.CameraPersp);
    defer camera.delete();
    camera.shape.CameraPersp.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });

    const focal_center = render.get_focal_plane_center(camera);
    var sphere_position = types.Vec3f32{ .x = 0, .y = 0, .z = 0 };
    var radius: f32 = 10;

    var intersect_ray_multiplier: f32 = undefined;

    var ray_direction_1 = render.get_ray_direction_from_focal_plane(
        camera,
        focal_center,
        30,
        30,
        1,
        0,
        0,
    );
    const intersect_1 = try jp_ray.check_ray_intersect_with_sphere(
        ray_direction_1,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_ray_multiplier,
    );

    try std.testing.expectEqual(intersect_1, false);
    var ray_direction_2 = render.get_ray_direction_from_focal_plane(
        camera,
        focal_center,
        30,
        30,
        1,
        15,
        15,
    );
    const intersect_2 = try jp_ray.check_ray_intersect_with_sphere(
        ray_direction_2,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_ray_multiplier,
    );
    try std.testing.expectEqual(intersect_2, true);

    var ray_direction_3 = render.get_ray_direction_from_focal_plane(
        camera,
        focal_center,
        30,
        30,
        1,
        29,
        29,
    );
    const intersect_3 = try jp_ray.check_ray_intersect_with_sphere(
        ray_direction_3,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_ray_multiplier,
    );
    try std.testing.expectEqual(intersect_3, false);
}
