const std = @import("std");
const allocator = std.heap.page_allocator;
const stdout = std.io.getStdOut().writer();

const types = @import("types.zig");
const math_utils = @import("math_utils.zig");
const jp_img = @import("jp_img.zig");
const jp_scene = @import("jp_scene.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");

// POUR LE MOMENT: implicit: 1px: "1" dans l'espace 3D.
// ALORS QUE: definir taille (fix) du plan focal
// induire la taille des PX de l'image en fonction du plan focal.
// iterer dessus.

// tirer rayon au MILIEU DU PIXEL !

fn get_ray_direction(
    camera: *const jp_object.JpObject,
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
    const ray_direction = screen_px_focal_plane_position.substract_vector(
        &camera.tmatrix.get_position(),
    );
    return ray_direction;
}

fn get_focal_plane_center(camera: *const jp_object.JpObject) types.Vec3f32 {
    // camera.pos + camera.direction * focal_length
    var weighted_direction = camera.shape.Camera.direction.product_scalar(
        camera.shape.Camera.focal_length,
    );
    var position = camera.tmatrix.get_position();
    return position.sum_vector(&weighted_direction);
}

fn check_ray_intersect_with_sphere(
    ray_direction: types.Vec3f32,
    ray_origin: types.Vec3f32,
    sphere_position: types.Vec3f32,
    sphere_radius: f32,
    intersect_position: *types.Vec3f32,
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
    if (t0 > t1) {
        t = t1;
    } else {
        t = t0;
    }

    intersect_position.* = ray_direction.product_scalar(t).sum_vector(&ray_origin);
    intersect_ray_multiplier.* = t;
    return true;
}

pub fn render(
    img: *jp_img.JpImg,
    camera: *jp_object.JpObject,
    scene: *jp_scene.JpScene,
) !void {
    const focal_center = get_focal_plane_center(camera);
    const camera_position = camera.tmatrix.get_position();

    const img_width = img.*.width;
    const img_height = img.*.height;
    var _x: u16 = 0;
    var _y: u16 = undefined;

    var _ray_direction: types.Vec3f32 = undefined;

    var _t_current: f32 = undefined;
    var _t_min: f32 = undefined;

    var _intersect_one_obj: bool = undefined;
    var _intersect_position: types.Vec3f32 = undefined;
    var _intersect_object: jp_object.JpObject = undefined;

    while (_x < img.width) : (_x += 1) {
        _y = img.height - 1;
        while (_y != 0) : (_y -= 1) {
            _ray_direction = get_ray_direction(
                camera,
                focal_center,
                img_width,
                img_height,
                _x,
                _y,
            );
            _intersect_one_obj = false;
            _t_min = 0;
            for (scene.objects.items) |obj| {
                if (obj.object_type == jp_object.JpObjectType.Mesh) {
                    unreachable;
                }
                var does_intersect: bool = undefined;
                switch (obj.shape.*) {
                    .Sphere => {
                        does_intersect = try check_ray_intersect_with_sphere(
                            _ray_direction,
                            camera_position,
                            obj.tmatrix.get_position(),
                            obj.shape.Sphere.radius,
                            &_intersect_position,
                            &_t_current,
                        );
                    },
                    else => {
                        unreachable;
                    },
                }
                if (does_intersect) {
                    _intersect_one_obj = true;
                } else {
                    continue;
                }
                if (_t_min == 0 or _t_current < _t_min) {
                    _intersect_object = obj.*;
                    _t_min = _t_current;
                }
            }
            if (_intersect_one_obj == false) {
                continue;
            }
            try jp_img.image_draw_at_px(
                img,
                _x,
                _y,
                _intersect_object.material.diffuse,
            );
        }
    }
}

test "get_focal_plane_center_on_valid_case" {
    var camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });
    const center = get_focal_plane_center(camera);
    try stdout.print("{d}, {d}, {d}", .{ center.x, center.y, center.z });
    try std.testing.expectEqual(center.x, 0);
    try std.testing.expectEqual(center.y, 0);
    try std.testing.expectEqual(center.z, -10);
}

test "get_ray_direction_on_valid_case" {
    const camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });
    const focal_center = get_focal_plane_center(camera);

    var ray_direction_1 = get_ray_direction(camera, focal_center, 30, 30, 0, 0);
    try std.testing.expectEqual(ray_direction_1.x, -15);
    try std.testing.expectEqual(ray_direction_1.y, -15);
    try std.testing.expectEqual(ray_direction_1.z, 10);

    var ray_direction_2 = get_ray_direction(camera, focal_center, 30, 30, 16, 20);
    try std.testing.expectEqual(ray_direction_2.x, 1);
    try std.testing.expectEqual(ray_direction_2.y, 5);
    try std.testing.expectEqual(ray_direction_2.z, 10);
}

test "check_ray_intersect_with_sphere_basic_test" {
    const camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });

    const focal_center = get_focal_plane_center(camera);
    var sphere_position = types.Vec3f32{ .x = 0, .y = 0, .z = 0 };
    var radius: f32 = 10;

    var intersect_position: types.Vec3f32 = undefined;
    var intersect_ray_multiplier: f32 = undefined;

    var ray_direction_1 = get_ray_direction(camera, focal_center, 30, 30, 0, 0);
    const intersect_1 = try check_ray_intersect_with_sphere(
        ray_direction_1,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_position,
        &intersect_ray_multiplier,
    );

    try std.testing.expectEqual(intersect_1, false);
    var ray_direction_2 = get_ray_direction(camera, focal_center, 30, 30, 15, 15);
    const intersect_2 = try check_ray_intersect_with_sphere(
        ray_direction_2,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_position,
        &intersect_ray_multiplier,
    );
    try std.testing.expectEqual(intersect_2, true);

    var ray_direction_3 = get_ray_direction(camera, focal_center, 30, 30, 29, 29);
    const intersect_3 = try check_ray_intersect_with_sphere(
        ray_direction_3,
        camera.tmatrix.get_position(),
        sphere_position,
        radius,
        &intersect_position,
        &intersect_ray_multiplier,
    );
    try std.testing.expectEqual(intersect_3, false);

    try std.testing.expectEqual(intersect_position.x, 0);
    try std.testing.expectEqual(intersect_position.y, 0);
    try std.testing.expectEqual(intersect_position.z, -10);
    try std.testing.expectEqual(intersect_ray_multiplier, 1);
}

test "render_one_sphere_at_center" {
    const camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });

    var img = try jp_img.image_create(30, 30);

    const sphere_1 = try jp_object.create_sphere();
    sphere_1.shape.Sphere.radius = 8;
    sphere_1.material = &jp_material.JP_MATERIAL_BASE_RED;

    var scene = try jp_scene.create_scene();
    try scene.add_object(sphere_1);

    try render(img, camera, scene);
    try jp_img.image_write_to_ppm(img, "render_one_sphere_at_center.ppm");
}

test "render_two_sphere_at_center" {
    const camera = try jp_object.create_camera();
    camera.shape.Camera.focal_length = 10;
    try camera.tmatrix.set_position(&types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -20,
    });

    var img = try jp_img.image_create(30, 30);

    const sphere_1 = try jp_object.create_sphere();
    sphere_1.shape.Sphere.radius = 7;
    sphere_1.material = &jp_material.JP_MATERIAL_BASE_RED;

    const sphere_2 = try jp_object.create_sphere();
    sphere_2.shape.Sphere.radius = 8;
    sphere_2.material = &jp_material.JP_MATERIAL_BASE_BLUE;

    try sphere_2.tmatrix.set_position(&types.Vec3f32{
        .x = 5,
        .y = 5,
        .z = -2,
    });

    var scene = try jp_scene.create_scene();
    try scene.add_object(sphere_1);
    try scene.add_object(sphere_2);

    try render(img, camera, scene);
    try jp_img.image_write_to_ppm(img, "render_two_sphere_at_center.ppm");
}
