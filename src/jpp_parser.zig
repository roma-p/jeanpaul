const std = @import("std");
const types = @import("types.zig");
const jp_img = @import("jp_img.zig");
const jp_ray = @import("jp_ray.zig");
const jp_scene = @import("jp_scene.zig");
const jp_color = @import("jp_color.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");
const jpp_format = @import("jpp_format.zig");

const PARSING_STATE = enum {
    SectionTypeGathered,
    EnteredSection,
    ExitSection,
};


pub const ErrorParsingJPP = error{ParsingError};

pub fn parse(file_path: []const u8) ErrorParsingJPP!bool {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buf: [1024]u8 = undefined;

    var current_section_type: []const u8 = undefined;

    var parsing_state: PARSING_STATE = PARSING_STATE.ExitSection;

    while (try file.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
        line = _split_on_comment(line);
        const words = try std.mem.split(u8, line, " ");

        switch (parsing_state) {
            .ExitSection => {
                current_section_type = words.next();
                parsing_state = PARSING_STATE.SectionTypeGathered;
            },
            .SectionTypeGathered => {
                const word = words.next();
                if (word[0] != SYMBOL_SECTION_BEGIN) {
                    return ErrorParsingJPP.ParsingError;
                }
                parsing_state = PARSING_STATE.EnteredSection;
            },
            .EnteredSection => {
                var word = words.next();
                if (word[0] != SYMBOL_SECTION_END) {
                    current_section_type = undefined;
                    parsing_state = PARSING_STATE.ExitSection;
                    continue;
                }
                const property_name = word;
                word = words.next();
                if (word == SYMBOL_MULTILINE_TYPE) {
                    break;
                }
                const property_value = word;
            },
        }
    }
}

fn _split_on_comment(str: []const u8) []const u8 {
    if (std.mem.indexOf(u8, str, SYMBOL_COMMENT)) |index| {
        return str[0..index];
    }
    return str;
}


fn _create_object(objet_type_as_str: []const u8) {
}

