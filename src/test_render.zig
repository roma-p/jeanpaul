const std = @import("std");
const render = @import("render.zig");
const types = @import("types.zig");
const jp_scene = @import("jp_scene.zig");
const jp_color = @import("jp_color.zig");
const jp_material = @import("jp_material.zig");
const jp_object = @import("jp_object.zig");

const JpObject = jp_object.JpObject;
const ShapeTypeId = jp_object.ShapeTypeId;

test "get_pixel_size" {
    const focal_length: f32 = 10;
    const field_of_view: f32 = 60;
    const img_width: f32 = 10;
    _ = try render.get_pixel_size(focal_length, field_of_view, img_width);
}

test "get_focal_plane_center_on_valid_case" {
    var camera = try JpObject.new("camera", ShapeTypeId.CameraPersp);
    defer camera.delete();
    camera.shape.CameraPersp.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });
    const center = render.get_focal_plane_center(camera);
    try std.testing.expectEqual(center.x, 0);
    try std.testing.expectEqual(center.y, 0);
    try std.testing.expectEqual(center.z, -10);
}

test "render.get_ray_direction_from_focal_plane_on_valid_case" {
    var camera = try JpObject.new("camera", ShapeTypeId.CameraPersp);
    defer camera.delete();
    camera.shape.CameraPersp.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });
    const focal_center = render.get_focal_plane_center(camera);

    var ray_direction_1 = render.get_ray_direction_from_focal_plane(
        camera,
        focal_center,
        30,
        30,
        1,
        0,
        0,
    );
    try std.testing.expectEqual(ray_direction_1.x, -14.5);
    try std.testing.expectEqual(ray_direction_1.y, -14.5);
    try std.testing.expectEqual(ray_direction_1.z, 10);

    var ray_direction_2 = render.get_ray_direction_from_focal_plane(
        camera,
        focal_center,
        30,
        30,
        1,
        16,
        20,
    );
    try std.testing.expectEqual(ray_direction_2.x, 1.5);
    try std.testing.expectEqual(ray_direction_2.y, 5.5);
    try std.testing.expectEqual(ray_direction_2.z, 10);
}

test "render_one_sphere_at_center" {
    var camera = try JpObject.new("camera", ShapeTypeId.CameraPersp);
    defer camera.delete();
    camera.shape.CameraPersp.focal_length = 10;
    camera.shape.CameraPersp.field_of_view = 60;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });

    var sphere_1 = try JpObject.new("sphere_1", ShapeTypeId.ImplicitSphere);
    defer sphere_1.delete();
    sphere_1.shape.ImplicitSphere.radius = 8;
    sphere_1.material = try jp_material.create_default_colored_material(
        jp_color.JP_COLOR_RED,
    );

    var light_1 = try JpObject.new("light_1", ShapeTypeId.LightOmni);
    defer light_1.delete();
    light_1.shape.LightOmni.color = jp_color.JP_COLOR_WHITE;
    try light_1.tmatrix.set_position(&types.Vec3f32{
        .x = 20,
        .y = 15,
        .z = -15,
    });

    var scene = try jp_scene.JpScene.new();
    scene.resolution = types.Vec2u16{ .x = 256, .y = 256 };
    try scene.add_object(sphere_1);
    try scene.add_light(light_1);

    try render.render_to_path(camera, scene, "render_one_sphere_at_center.ppm");
}

test "render_two_sphere_at_center" {
    var camera = try JpObject.new("camera", ShapeTypeId.CameraPersp);
    defer camera.delete();
    camera.shape.CameraPersp.focal_length = 10;
    camera.shape.CameraPersp.field_of_view = 70;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -30,
    });

    var sphere_1 = try JpObject.new("sphere_1", ShapeTypeId.ImplicitSphere);
    defer sphere_1.delete();
    sphere_1.shape.ImplicitSphere.radius = 7;
    sphere_1.material = try jp_material.create_default_colored_material(
        jp_color.JP_COLOR_RED,
    );

    var sphere_2 = try JpObject.new("sphere_2", ShapeTypeId.ImplicitSphere);
    defer sphere_2.delete();
    sphere_2.shape.ImplicitSphere.radius = 8;
    sphere_2.material = try jp_material.create_default_colored_material(
        jp_color.JP_COLOR_BLUE,
    );
    try sphere_2.tmatrix.set_position(&types.Vec3f32{
        .x = 5,
        .y = 5,
        .z = -2,
    });

    var light_1 = try JpObject.new("light_1", ShapeTypeId.LightOmni);
    defer light_1.delete();
    light_1.shape.LightOmni.color = jp_color.JP_COLOR_WHITE;
    try light_1.tmatrix.set_position(&types.Vec3f32{
        .x = 20,
        .y = 20,
        .z = -20,
    });

    var scene = try jp_scene.JpScene.new();
    scene.resolution = types.Vec2u16{ .x = 256, .y = 256 };
    try scene.add_object(sphere_1);
    try scene.add_object(sphere_2);
    try scene.add_light(light_1);

    try render.render_to_path(camera, scene, "render_two_sphere_at_center.ppm");
}
test "render_two_sphere_distanced" {
    var camera = try JpObject.new("camera", ShapeTypeId.CameraPersp);
    defer camera.delete();
    camera.shape.CameraPersp.focal_length = 10;
    camera.shape.CameraPersp.field_of_view = 70;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -30,
    });

    var sphere_1 = try JpObject.new("sphere_1", ShapeTypeId.ImplicitSphere);
    defer sphere_1.delete();
    sphere_1.shape.ImplicitSphere.radius = 7;
    sphere_1.material = try jp_material.create_default_colored_material(
        jp_color.JP_COLOR_RED,
    );
    try sphere_1.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 5,
        .z = 0,
    });

    var sphere_2 = try JpObject.new("sphere_2", ShapeTypeId.ImplicitSphere);
    defer sphere_2.delete();
    sphere_2.shape.ImplicitSphere.radius = 6;
    sphere_2.material = try jp_material.create_default_colored_material(
        jp_color.JP_COLOR_BLUE,
    );
    try sphere_2.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = -5,
        .z = 0,
    });

    var light_1 = try JpObject.new("light_1", ShapeTypeId.LightOmni);
    defer light_1.delete();
    light_1.shape.LightOmni.color = jp_color.JP_COLOR_WHITE;
    try light_1.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 10,
        .z = 0,
    });

    var scene = try jp_scene.JpScene.new();
    scene.resolution = types.Vec2u16{ .x = 256, .y = 256 };
    try scene.add_object(sphere_1);
    try scene.add_object(sphere_2);
    try scene.add_light(light_1);

    try render.render_to_path(camera, scene, "render_two_sphere_distanced.ppm");
}
