const std = @import("std");
const jp_object = @import("jp_object.zig");

test "create_camera" {
    const camera = try jp_object.create_camera();
    try std.testing.expectEqual(camera.shape.Camera.focal_length, 10);
    jp_object.delete_obj(camera);
}

test "create_sphere" {
    const sphere = try jp_object.create_sphere();
    try std.testing.expectEqual(sphere.shape.Sphere.radius, 10);
    jp_object.delete_obj(sphere);
}

test "create_light" {
    const lgt = try jp_object.create_light_omni();
    try std.testing.expectEqual(lgt.shape.LightOmni.intensity, 70);
    jp_object.delete_obj(lgt);
}
