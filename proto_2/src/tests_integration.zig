const definitions = @import("definitions.zig");
const data_render_settings = @import("data_render_settings.zig");

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

    const handle_mat_red_metal = try controller_mat.add_material(
        "red_metal",
        Material{ .Metal = .{
            .base_color = data_color.Color{ .r = 1, .g = 0.3, .b = 0.4 },
            .base = 1,
            .fuzz = 0.1,
        } },
    );

    const handle_mat_sky = try controller_mat.add_material(
        "blue_sky",
        Material{ .DiffuseLight = .{
            .color = data_color.Color{ .r = 0.5, .g = 0.7, .b = 1 },
            .intensity = 1,
        } },
    );

    const handle_light_green = try controller_mat.add_material(
        "light_green",
        Material{ .Lambertian = .{
            .base_color = data_color.Color{ .r = 0.2, .g = 0.7, .b = 0.4 },
        } },
    );

    const handle_mat_light_ball = try controller_mat.add_material(
        "light_ball",
        Material{ .DiffuseLight = .{
            .color = data_color.COLOR_WHITE,
            .intensity = 50,
            .exposition = 2,
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
        handle_light_green,
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
        TMatrix.create_at_position(Vec3f32{ .x = -12, .y = 0, .z = 4 }),
        handle_mat_light_ball,
    );
    _ = try controller_object.add_shape(
        "sphere_3",
        Shape{ .ImplicitSphere = .{ .radius = 5 } },
        TMatrix.create_at_position(Vec3f32{ .x = 12, .y = 0, .z = 4 }),
        handle_mat_red_metal,
    );

    const handle_cam: data_handles.HandleCamera = try controller_object.add_camera(
        "camera_1",
        Camera{ .Perspective = .{} },
        TMatrix.create_at_position(Vec3f32{ .x = 0, .y = 0, .z = 47 }),
    );

    controller_scene.render_settings.width = 1920;
    controller_scene.render_settings.height = 1080;
    controller_scene.render_settings.tile_size = 128;
    controller_scene.render_settings.samples = 4;
    controller_scene.render_settings.samples_antialiasing = 4;
    controller_scene.render_settings.bounces = 6;
    controller_scene.render_settings.render_type = data_render_settings.RenderType.Tile;
    controller_scene.render_settings.render_single_px_x = 320;
    controller_scene.render_settings.render_single_px_y = 240;
    controller_scene.render_settings.color_space = data_render_settings.ColorSpace.DefaultGamma2;
    controller_scene.render_settings.collision_acceleration = data_render_settings.CollisionAccelerationMethod.BvhEqualSize;

    try controller_aov.add_aov_standard(AovStandard.Beauty);
    try controller_aov.add_aov_standard(AovStandard.Alpha);
    try controller_aov.add_aov_standard(AovStandard.Albedo);
    try controller_aov.add_aov_standard(AovStandard.Normal);
    try controller_aov.add_aov_standard(AovStandard.Depth);
    try controller_aov.add_aov_standard(AovStandard.Direct);
    try controller_aov.add_aov_standard(AovStandard.Indirect);

    try controller_aov.add_aov_standard(AovStandard.Emission);
    try controller_aov.add_aov_standard(AovStandard.Diffuse);
    try controller_aov.add_aov_standard(AovStandard.DiffuseDirect);
    try controller_aov.add_aov_standard(AovStandard.DiffuseIndirect);
    try controller_aov.add_aov_standard(AovStandard.Specular);
    try controller_aov.add_aov_standard(AovStandard.SpecularDirect);
    try controller_aov.add_aov_standard(AovStandard.SpecularIndirect);

    try controller_aov.add_aov_standard(AovStandard.DebugCheeseNan);

    // try controller_aov.add_aov_standard(AovStandard.DebugTimePerPixel);

    var renderer = try Renderer.init(&controller_scene);
    defer renderer.deinit();

    try renderer.render(handle_cam, "tests", "test_render_image");
}
