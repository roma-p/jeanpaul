const std = @import("std");
const jpp_parser = @import("jpp_parser.zig");
const jpp_format = @import("jpp_format.zig");
const jp_scene = @import("jp_scene.zig");

const JppParser = jpp_parser.JppParser;
const ErrorParsingJPP = jpp_parser.ErrorParsingJPP;
const TypeNotFound = jpp_format.TypeNotFound;

test "valid_jpp_file" {
    _ = try JppParser.parse("etc/jpp_example.jpp");
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
