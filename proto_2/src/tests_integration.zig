const definitions = @import("definitions.zig");

const Material = definitions.Material;
const Shape = definitions.Shape;
const Camera = definitions.Camera;
const Environment = definitions.Environment;
const AovStandard = definitions.AovStandardEnum;

const data_color = @import("data_color.zig");
const data_handles = @import("data_handle.zig");

const maths_vec = @import("maths_vec.zig");
const maths_mat = @import("maths_mat.zig");
const maths_tmat = @import("maths_tmat.zig");

const Vec3f32 = maths_vec.Vec3f32;
const TMatrix = maths_tmat.TMatrix;

const ControllereScene = @import("controller_scene.zig");
const Renderer = @import("renderer.zig");

test "prepare_render" {
    var controller_scene = try ControllereScene.init();
    defer controller_scene.deinit();

    var controller_object = &controller_scene.controller_object;
    var controller_aov = &controller_scene.controller_aov;
    var controller_mat = &controller_scene.controller_material;

    // -- MATERIAL --

    _ = try controller_mat.add_material(
        "red",
        Material{ .Lambertian = .{ .base_color = data_color.COLOR_RED } },
    );

    // const handle_mat_lambert_blue = try controller_mat.add_material(
    //     "light_blue",
    //     Material{ .Lambertian = .{ .base_color = data_color.Color{ .r = 0.5, .g = 0.7, .b = 1 }, .base = 1 } },
    // );

    const handle_mat_sky = try controller_mat.add_material(
        "blue_sky",
        Material{ .DiffuseLight = .{ .color = data_color.Color{ .r = 0.5, .g = 0.7, .b = 1 }, .intensity = 1 } },
    );

    const handle_mat_light_ball = try controller_mat.add_material(
        "light_ball",
        Material{ .DiffuseLight = .{
            .color = data_color.Color{ .r = 0.5, .g = 0.7, .b = 1 },
            .intensity = 50,
            .exposition = 4,
            .decay_mode = definitions.LightDecayMode.Quadratic,
        } },
    );

    const handle_mat_lambert_grey = try controller_mat.add_material(
        "grey",
        Material{ .Lambertian = .{
            .base_color = data_color.COLOR_GREY,
            .base = 1,
        } },
    );

    // -- ENV --

    _ = try controller_object.add_env(
        "sky",
        Environment{ .SkyDome = .{ .handle_material = handle_mat_sky } },
    );

    // -- SHAPE --

    _ = try controller_object.add_shape(
        "ground",
        Shape{ .ImplicitPlane = .{ .normal = Vec3f32.create_y() } },
        TMatrix.create_at_position(Vec3f32{ .x = 0, .y = -5, .z = 0 }),
        handle_mat_lambert_grey,
    );

    _ = try controller_object.add_shape(
        "sphere_1",
        Shape{ .ImplicitSphere = .{ .radius = 5 } },
        TMatrix.create_at_position(Vec3f32{ .x = 0, .y = 0, .z = 4 }),
        handle_mat_lambert_grey,
    );

    _ = try controller_object.add_shape(
        "sphere_2",
        Shape{ .ImplicitSphere = .{ .radius = 5 } },
        TMatrix.create_at_position(Vec3f32{ .x = -12, .y = 7, .z = 4 }),
        handle_mat_light_ball,
    );

    const handle_cam: data_handles.HandleCamera = try controller_object.add_camera(
        "camera_1",
        Camera{ .Perspective = .{} },
        TMatrix.create_at_position(Vec3f32{ .x = 0, .y = 0, .z = 47 }),
    );

    controller_scene.render_settings.width = 1920;
    controller_scene.render_settings.height = 1080;
    controller_scene.render_settings.tile_size = 128;
    controller_scene.render_settings.samples = 7;
    controller_scene.render_settings.bounces = 200;

    try controller_aov.add_aov_standard(AovStandard.Beauty);
    try controller_aov.add_aov_standard(AovStandard.Alpha);
    try controller_aov.add_aov_standard(AovStandard.Albedo);
    try controller_aov.add_aov_standard(AovStandard.Normal);
    try controller_aov.add_aov_standard(AovStandard.Depth);
    try controller_aov.add_aov_standard(AovStandard.Direct);
    try controller_aov.add_aov_standard(AovStandard.Indirect);

    var renderer = Renderer.init(&controller_scene);
    defer renderer.deinit();

    try renderer.render(handle_cam, "tests", "test_render_image");
}
