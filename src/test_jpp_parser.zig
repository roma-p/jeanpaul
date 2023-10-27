const std = @import("std");
const types = @import("types.zig");
const jpp_parser = @import("jpp_parser.zig");
const jpp_format = @import("jpp_format.zig");
const jp_scene = @import("jp_scene.zig");

const JppParser = jpp_parser.JppParser;
const ErrorParsingJPP = jpp_parser.ErrorParsingJPP;
const TypeNotFound = jpp_format.TypeNotFound;
const JpSceneError = jp_scene.JpSceneError;

test "valid_jpp_file" {
    const scene = try JppParser.parse("etc/jpp_example.jpp");

    // check camera.
    const camera = try scene.get_object("camera_main");
    try std.testing.expectEqual(camera.shape.CameraPersp.focal_length, 13);
    try std.testing.expectEqual(camera.shape.CameraPersp.field_of_view, 60);
    try std.testing.expectEqual(scene.render_camera, camera);
    try std.testing.expectEqual(
        camera.tmatrix.get_position().check_is_equal(
            &types.Vec3f32{ .x = 1, .y = 2, .z = 3 },
        ),
        true,
    );

    // check lambert1
    const lambert1 = try scene.get_material("lambert1");
    try std.testing.expectEqual(lambert1.mat.Lambert.kd_intensity, 0.45);
    try std.testing.expectEqual(lambert1.mat.Lambert.kd_color.r, 1);
    try std.testing.expectEqual(lambert1.mat.Lambert.kd_color.g, 0);
    try std.testing.expectEqual(lambert1.mat.Lambert.kd_color.b, 0);

    // check sphere1
    const sphere = try scene.get_object("somesphere");
    try std.testing.expectEqual(sphere.shape.ImplicitSphere.radius, 5);
    try std.testing.expectEqual(
        sphere.tmatrix.get_position().check_is_equal(
            &types.Vec3f32{ .x = 0, .y = 0, .z = 0 },
        ),
        true,
    );
    try std.testing.expectEqual(lambert1, sphere.material);
}

test "valid_empty_jpp_file" {
    _ = try JppParser.parse("etc/jpp_example_empty_section.jpp");
}

test "wrong_vector_size" {
    _ = try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_vector_wrong_size.jpp"),
    );
}

test "wrong_matrix_size_x" {
    _ = try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_matrix_wrong_size_x.jpp"),
    );
}

test "wrong_matrix_size_y" {
    _ = try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_matrix_wrong_size_y.jpp"),
    );
}

test "missing_delimiter" {
    _ = try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_missing_delimiter.jpp"),
    );
}

test "clone_mat" {
    _ = try std.testing.expectError(
        jp_scene.JpSceneError.NameNotAvailable,
        JppParser.parse("etc/jpp_clone_map.jpp"),
    );
}

test "wrong_type" {
    _ = try std.testing.expectError(
        ErrorParsingJPP.WrongType,
        JppParser.parse("etc/jpp_wrong_type.jpp"),
    );
}

test "wrong_color" {
    _ = try std.testing.expectError(
        ErrorParsingJPP.WrongType,
        JppParser.parse("etc/jpp_unvalid_color_def.jpp"),
    );
    _ = try std.testing.expectError(
        ErrorParsingJPP.WrongType,
        JppParser.parse("etc/jpp_unvalid_color_def_2.jpp"),
    );
}

test "unknown_material_type" {
    _ = try std.testing.expectError(
        TypeNotFound.MaterialTypeNotFound,
        JppParser.parse("etc/jpp_unknown_material_type.jpp"),
    );
}

test "unknown_section_type" {
    _ = try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_unknown_section_type.jpp"),
    );
}

test "render_camera_not_found" {
    _ = try std.testing.expectError(
        JpSceneError.ObjectNotFound,
        JppParser.parse("etc/jpp_render_camera_not_found.jpp"),
    );
}
