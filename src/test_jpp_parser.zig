const std = @import("std");
const jpp_parser = @import("jpp_parser.zig");

const JppParser = jpp_parser.JppParser;
const ErrorParsingJPP = jpp_parser.ErrorParsingJPP;

test "valid_jpp_file" {
    try JppParser.parse("etc/jpp_example.jpp");
}

test "valid_empty_jpp_file" {
    try JppParser.parse("etc/jpp_example_empty_section.jpp");
}

test "wrong_vector_size" {
    try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_vector_wrong_size.jpp"),
    );
}

test "wrong_matrix_size_x" {
    try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_matrix_wrong_size_x.jpp"),
    );
}

test "wrong_matrix_size_y" {
    try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_matrix_wrong_size_y.jpp"),
    );
}

test "missing_delimiter" {
    try std.testing.expectError(
        ErrorParsingJPP.ParsingError,
        JppParser.parse("etc/jpp_missing_delimiter.jpp"),
    );
}
