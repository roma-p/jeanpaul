const std = @import("std");
const render = @import("render.zig");
const types = @import("types.zig");
const jp_img = @import("jp_img.zig");
const jp_scene = @import("jp_scene.zig");
const jp_color = @import("jp_color.zig");
const jp_material = @import("jp_material.zig");
const jp_object = @import("jp_object.zig");

test "get_pixel_size" {
    const focal_length: f32 = 10;
    const field_of_view: f32 = 60;
    const img_width: f32 = 10;
    _ = try render.get_pixel_size(focal_length, field_of_view, img_width);
}

test "get_focal_plane_center_on_valid_case" {
    var camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
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

test "render.get_ray_direction_on_valid_case" {
    const camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });
    const focal_center = render.get_focal_plane_center(camera);

    var ray_direction_1 = render.get_ray_direction(camera, focal_center, 30, 30, 1, 0, 0);
    try std.testing.expectEqual(ray_direction_1.x, -14.5);
    try std.testing.expectEqual(ray_direction_1.y, -14.5);
    try std.testing.expectEqual(ray_direction_1.z, 10);

    var ray_direction_2 = render.get_ray_direction(camera, focal_center, 30, 30, 1, 16, 20);
    try std.testing.expectEqual(ray_direction_2.x, 1.5);
    try std.testing.expectEqual(ray_direction_2.y, 5.5);
    try std.testing.expectEqual(ray_direction_2.z, 10);
}

test "render.check_ray_intersect_with_sphere_basic_test" {
    const camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });

    const focal_center = render.get_focal_plane_center(camera);
    var sphere_position = types.Vec3f32{ .x = 0, .y = 0, .z = 0 };
    var radius: f32 = 10;

    var intersect_position: types.Vec3f32 = undefined;
    var intersect_ray_multiplier: f32 = undefined;

    var ray_direction_1 = render.get_ray_direction(camera, focal_center, 30, 30, 1, 0, 0);
    const intersect_1 = try render.check_ray_intersect_with_sphere(
        ray_direction_1,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_position,
        &intersect_ray_multiplier,
    );

    try std.testing.expectEqual(intersect_1, false);
    var ray_direction_2 = render.get_ray_direction(camera, focal_center, 30, 30, 1, 15, 15);
    const intersect_2 = try render.check_ray_intersect_with_sphere(
        ray_direction_2,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_position,
        &intersect_ray_multiplier,
    );
    try std.testing.expectEqual(intersect_2, true);

    var ray_direction_3 = render.get_ray_direction(camera, focal_center, 30, 30, 1, 29, 29);
    const intersect_3 = try render.check_ray_intersect_with_sphere(
        ray_direction_3,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_position,
        &intersect_ray_multiplier,
    );
    try std.testing.expectEqual(intersect_3, false);
}

test "render_one_sphere_at_center" {
    const camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    camera.shape.Camera.field_of_view = 120;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });

    var img = try jp_img.image_create(30, 30);

    const sphere_1 = try jp_object.create_sphere();
    sphere_1.shape.Sphere.radius = 8;
    sphere_1.material = try jp_material.create_default_colored_material(
        jp_color.JP_COLOR_RED,
    );

    var scene = try jp_scene.create_scene();
    try scene.add_object(sphere_1);

    try render.render(img, camera, scene);
    try jp_img.image_write_to_ppm(img, "render_one_sphere_at_center.ppm");
}

test "render_two_sphere_at_center" {
    const camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    camera.shape.Camera.field_of_view = 90;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -30,
    });

    var img = try jp_img.image_create(256, 256);

    const sphere_1 = try jp_object.create_sphere();
    sphere_1.shape.Sphere.radius = 7;
    sphere_1.material = try jp_material.create_default_colored_material(
        jp_color.JP_COLOR_RED,
    );

    const sphere_2 = try jp_object.create_sphere();
    sphere_2.shape.Sphere.radius = 8;
    sphere_2.material = try jp_material.create_default_colored_material(
        jp_color.JP_COLOR_BLUE,
    );

    try sphere_2.tmatrix.set_position(&types.Vec3f32{
        .x = 5,
        .y = 5,
        .z = -2,
    });

    var scene = try jp_scene.create_scene();
    try scene.add_object(sphere_1);
    try scene.add_object(sphere_2);

    try render.render(img, camera, scene);
    try jp_img.image_write_to_ppm(img, "render_two_sphere_at_center.ppm");
}
