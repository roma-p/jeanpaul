const std = @import("std");
const types = @import("types.zig");
const jp_object = @import("jp_object.zig");

// test "get_normal_of_sphere" {
//     const sphere = try jp_object.create_sphere("sphere_1");
//     sphere.shape.Sphere.radius = 10;
//     const position = types.Vec3f32{ .x = 0, .y = 0, .z = -10 };
//     _ = jp_object.get_normal_at_position(sphere, position);
// }

test "create_camera" {
    var camera = try jp_object.JpObject.new(
        "camera1",
        jp_object.ShapeTypeId.CameraPersp,
    );
    camera.shape.CameraPersp.focal_length = 5;
    camera.delete();
}

test "create_sphere" {
    var sphere = try jp_object.JpObject.new(
        "sphere1",
        jp_object.ShapeTypeId.ImplicitSphere,
    );
    sphere.shape.ImplicitSphere.radius = 7;
    sphere.delete();
}

test "create_light" {
    var light1 = try jp_object.JpObject.new(
        "light1",
        jp_object.ShapeTypeId.LightOmni,
    );
    light1.shape.LightOmni.color.r = 255;
    light1.delete();
}
