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

    const handle_mat_default = try controller_mat.add_material(
        "default",
        Material{ .Lambertian = .{ .base_color = data_color.COLOR_RED } },
    );

    const handle_mat_sky = try controller_mat.add_material(
        "sky",
        Material{ .Lambertian = .{ .base_color = data_color.COLOR_BLUE } },
    );

    _ = try controller_object.add_shape(
        "sphere_1",
        Shape{ .ImplicitSphere = .{ .radius = 45 } },
        TMatrix.create_at_position(Vec3f32{ .x = 1, .y = 2, .z = 3 }),
        handle_mat_default,
    );

    _ = try controller_object.add_shape(
        "plane_1",
        Shape{ .ImplicitPlane = .{ .normal = Vec3f32.create_y() } },
        TMatrix.create_at_position(Vec3f32{ .x = 1, .y = 2, .z = 3 }),
        handle_mat_default,
    );

    _ = try controller_object.add_env(
        "sky",
        Environment{ .SkyDome = .{ .handle_material = handle_mat_sky } },
    );

    const handle_cam: data_handles.HandleCamera = try controller_object.add_camera(
        "camera1",
        Camera{ .Perspective = .{} },
        TMatrix.create_at_position(Vec3f32{ .x = 1, .y = 2, .z = 3 }),
    );

    controller_scene.render_settings.width = 1920;
    controller_scene.render_settings.height = 1080;
    controller_scene.render_settings.tile_size = 128;
    controller_scene.render_settings.samples = 2;

    try controller_aov.add_aov_standard(AovStandard.Beauty);
    try controller_aov.add_aov_standard(AovStandard.Alpha);
    try controller_aov.add_aov_standard(AovStandard.Normal);

    var renderer = Renderer.init(&controller_scene);
    defer renderer.deinit();

    try renderer.render(handle_cam, "tests", "test_render_image");
}
