const std = @import("std");
const types = @import("types.zig");
const jp_object = @import("jp_object.zig");

test "create_camera" {
    const camera = try jp_object.create_camera("camera");
    try std.testing.expectEqual(camera.shape.Camera.focal_length, 10);
    jp_object.delete_obj(camera);
}

test "create_sphere" {
    const sphere = try jp_object.create_sphere("sphere_1");
    try std.testing.expectEqual(sphere.shape.Sphere.radius, 10);
    jp_object.delete_obj(sphere);
}

test "create_light" {
    const lgt = try jp_object.create_light_omni("light_1");
    try std.testing.expectEqual(lgt.shape.LightOmni.color.r, 0.5);
    jp_object.delete_obj(lgt);
}

test "get_normal_of_sphere" {
    const sphere = try jp_object.create_sphere("sphere_1");
    sphere.shape.Sphere.radius = 10;
    const position = types.Vec3f32{ .x = 0, .y = 0, .z = -10 };
    _ = jp_object.get_normal_at_position(sphere, position);
}
