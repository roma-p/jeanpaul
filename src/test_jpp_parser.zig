const std = @import("std");
const jpp_parser = @import("jpp_parser.zig");
const jp_scene = @import("jp_scene.zig");

const JppParser = jpp_parser.JppParser;
const ErrorParsingJPP = jpp_parser.ErrorParsingJPP;

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
