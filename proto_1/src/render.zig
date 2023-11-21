const std = @import("std");
const allocator = std.heap.page_allocator;
const stdout = std.io.getStdOut().writer();

const types = @import("types.zig");
const zig_utils = @import("zig_utils.zig");
const jp_img = @import("jp_img.zig");
const jp_ray = @import("jp_ray.zig");
const jp_scene = @import("jp_scene.zig");
const jp_color = @import("jp_color.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");
const render_shader = @import("render_shader.zig");

pub fn render_to_path(
    camera: *jp_object.JpObject,
    scene: *jp_scene.JpScene,
    filename: []const u8,
) !void {
    std.log.info("rendering to: {s}", .{filename});
    var img = try jp_img.JpImg.new(scene.resolution.x, scene.resolution.y);
    defer img.delete();

    try render(img, camera, scene);
    try img.image_write_to_ppm(filename);
}

pub fn render(
    img: *jp_img.JpImg,
    camera: *jp_object.JpObject,
    scene: *jp_scene.JpScene,
) !void {
    const focal_center = get_focal_plane_center(camera);

    const img_width: f32 = zig_utils.cast_u16_to_f32(img.*.width);
    const img_height: f32 = zig_utils.cast_u16_to_f32(img.*.height);

    const pixel_size = try get_pixel_size(
        camera.shape.CameraPersp.focal_length,
        camera.shape.CameraPersp.field_of_view,
        img_width,
    );

    var _x: u16 = 0;
    var _y: u16 = undefined;

    var _hit = try jp_ray.JpRayHit.new();
    defer _hit.delete();

    const sample_number = scene.get_samples_number();
    const sample_number_as_f32: f32 = @floatFromInt(sample_number);
    const inverted_sample_number: f32 = 1 / sample_number_as_f32;

    const RndGen = std.rand.DefaultPrng;
    var rnd = RndGen.init(0);

    while (_x < img.width) : (_x += 1) {
        _y = img.height - 1;
        while (_y != 0) : (_y -= 1) {
            var _sample: usize = 0;
            while (_sample < sample_number) : (_sample += 1) {
                var ray_direction = get_ray_direction_from_focal_plane(
                    camera,
                    focal_center,
                    img_width,
                    img_height,
                    pixel_size,
                    zig_utils.cast_u16_to_f32(_x),
                    zig_utils.cast_u16_to_f32(_y),
                    &rnd,
                );

                var bounce_number: usize = 0;
                var color_at_px = try render_pixel(
                    scene,
                    camera.tmatrix.get_position(),
                    ray_direction,
                    _hit,
                    &rnd,
                    &bounce_number,
                );

                color_at_px = color_at_px.multiply(inverted_sample_number);
                img.image_add_at_px(_x, _y, color_at_px);
            }
        }
    }
}

pub fn render_pixel(
    scene: *jp_scene.JpScene,
    ray_origin: types.Vec3f32,
    ray_direction: types.Vec3f32,
    hit: *jp_ray.JpRayHit,
    rnd: *std.rand.DefaultPrng,
    bounce_number: *usize,
) !jp_color.JpColor {
    var color_at_px: jp_color.JpColor = jp_color.JP_COLOR_BlACK;

    var intersect_one_obj = try jp_ray.shot_ray_on_physical_objects(
        ray_origin,
        hit,
        ray_direction,
        scene,
    );
    if (!intersect_one_obj) {
        return color_at_px;
    }

    var object: jp_object.JpObject = hit.object.*;
    var position: types.Vec3f32 = hit.position.*;
    var normal = jp_object.get_normal_at_position(&object, position);

    // if special shader, handled here. Otherwise if pbr, handled later.
    switch (hit.object.material.mat.*) {
        .AovAlpha => color_at_px = try render_shader.render_aov_alpha(
            object.material,
        ),
        .AovNormal => color_at_px = try render_shader.render_aov_normal(normal),
        .Lambert => {},
    }

    // getting initial color.
    color_at_px = try render_shader.render_lambert(
        position,
        normal,
        object.material,
        scene,
    );

    const bounce_max: usize = 7;
    if (bounce_number.* == bounce_max) return color_at_px;
    bounce_number.* += 1;

    // getting color from bounced rays.
    var bounce_direction = normal.gen_random_hemisphere_normalized(rnd);
    var bounce_color_at_px = try render_pixel(
        scene,
        hit.position.*,
        bounce_direction,
        hit,
        rnd,
        bounce_number,
    );

    const reflectance_factor: f32 = 0.7;
    bounce_color_at_px = bounce_color_at_px.multiply(reflectance_factor);
    color_at_px = color_at_px.sum_color(bounce_color_at_px);

    return color_at_px;
}

pub fn get_pixel_size(
    focal_length: f32,
    field_of_view: f32,
    img_width: f32,
) !f32 {
    const half_fov: f32 = field_of_view / 2;
    const half_fov_radiant: f32 = half_fov * (std.math.pi / 180.0);
    const focal_plane_width: f32 = (@tan(half_fov_radiant) * focal_length) * 2;
    const pixel_size: f32 = focal_plane_width / img_width;
    return pixel_size;
}

pub fn get_ray_direction_from_focal_plane(
    camera: *const jp_object.JpObject,
    focal_plane_center: types.Vec3f32,
    screen_width: f32,
    screen_height: f32,
    pixel_size: f32,
    x: f32,
    y: f32,
    rnd: *std.rand.DefaultPrng,
) types.Vec3f32 {
    const rand_1 = (rnd.random().float(f32) * pixel_size) - pixel_size / 2;
    const rand_2 = (rnd.random().float(f32) * pixel_size) - pixel_size / 2;

    // + pixel_size / 2 -> hitting the middle of the pixel
    const focal_plane_center_to_px_position = types.Vec3f32{
        .x = (x - screen_width / 2) * pixel_size + pixel_size / 2 + rand_1,
        .y = (y - screen_height / 2) * pixel_size + pixel_size / 2 + rand_2,
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

pub fn get_focal_plane_center(camera: *const jp_object.JpObject) types.Vec3f32 {
    // camera.pos + camera.direction * focal_length
    const camera_direction = get_camera_direction(camera);
    var weighted_direction = camera_direction.product_scalar(
        camera.shape.CameraPersp.focal_length,
    );
    var position = camera.tmatrix.get_position();
    return position.sum_vector(&weighted_direction);
}

pub fn get_camera_direction(camera: *const jp_object.JpObject) types.Vec3f32 {
    return camera.tmatrix.multiply_with_vec3(
        &camera.shape.CameraPersp.DIRECTION,
    ).normalize();
}
