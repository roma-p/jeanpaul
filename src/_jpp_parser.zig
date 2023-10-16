const std = @import("std");
const allocator = std.heap.page_allocator;
const types = @import("types.zig");
const jp_img = @import("jp_img.zig");
const jp_ray = @import("jp_ray.zig");
const jp_scene = @import("jp_scene.zig");
const jp_color = @import("jp_color.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");
const jpp_format = @import("jpp_format.zig");

// FIXME: rewrite it line by line... and with tests...

const ParsingState = enum {
    SectionTypeGathered,
    EnteredSection,
    ExitSection,
    ParsingVector,
    ParsingMatrix,
};

const ParsingSection =  struct {
    section_type_name: []u8 = undefined,
    property_list: std.ArrayList(*ParsingProperty) = undefined,

    const Self = @This();

    pub fn new() !*Self {
        var instance = try allocator.create(Self);
        instance.* = Self{
            .section_type_name = undefined,
            .property_list = try std.ArrayList(*ParsingProperty).initCapacity(allocator, 5),
        };
        return instance;
    }

    pub fn delete(self: *Self) void {
        self.property_list.deinit();
        allocator.destroy(self);
    }

};

const ParsingProperty = struct {
    name: []u8,
    value: ParsingPropertyValue,

    const Self = @This();

    pub fn new_number(name: []u8, number: f32) Self{
        var instance = Self._new(name);
        instance.value.* = ParsingPropertyValue{.Number = number};
        return instance;
    }

    pub fn new_string(name: []u8, string: []u8) Self{
        var instance = Self._new(name);
        instance.value.* = ParsingPropertyValue{.String = string};
        return instance;
    }

    pub fn new_matrix(name: []u8, x_size:u16, y_size:u16) Self{
        var instance = Self._new(name);
        instance.value.* = ParsingPropertyValue{.Matrix = ParsingPropertyMatrix.new(x_size, y_size),};
        return instance;
    }

    pub fn new_vector(name: []u8, size:u16) Self{
        var instance = Self._new(name);
        instance.value.* = ParsingPropertyValue{.Vector = ParsingPropertyVector.new(size)};
        return instance;
    }

    fn _new(name: []u8) Self {
        var instance = try allocator.create(Self);
        var value = try allocator.create(ParsingPropertyValue);
        instance.* = Self{.name = name, .value = value};
        return instance;
    }

    pub fn delete(self: *Self) void {
        switch(self.value) {
            .Matrix => self.value.Matrix.delete(),
            .Vector => self.value.Vector.delete(),
            else => {},
        }
        allocator.destroy(self.value);
        allocator.destroy(self);
    }
};

const ParsingPropertyValue = union(enum){
    Number: f32,
    String : []u8,
    Matrix: ParsingPropertyMatrix,
    Vector: ParsingPropertyVector,
};


const ParsingPropertyMatrix = struct {
    x_size: u16 = undefined,
    y_size: u16 = undefined,
    matrix: [][]f32 = undefined,

    const Self = @This();

    pub fn new(x_size: u16, y_size: u16) !*Self {
        var instance = try allocator.create(Self);
        instance.* = Self{
            .x_size = x_size,
            .y_size = y_size,
            .matrix = types.matrix_f32_create(x_size, y_size),
        };
        return instance;
    }

    pub fn delete(self: *Self) void {
        types.matrix_f32_delete(self.matrix);
        allocator.destroy(self);
    }
};

const ParsingPropertyVector = struct {
    size: u16 = undefined,
    vector: []f32 = undefined,

    const Self = @This();

    pub fn new(size: u16) !*Self {
        var instance = try allocator.create(Self);
        instance.* = Self{
            .size = size,
            .vector = [size]f32
        };
        return instance;
    }

    pub fn delete(self: *Self) void {
        allocator.destroy(self);
    }
};


pub const ErrorParsingJPP = error{ParsingError};

pub fn parse(file_path: []const u8) ErrorParsingJPP!bool {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buf: [1024]u8 = undefined;

    var i_parsing_section: ParsingSection = undefined;
    var i_parsing_state: ParsingState = ParsingState.ExitSection;
    var i_line_number: u16 = 0;

    while (try file.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
        line = get_uncommented_line(line);
        i_line_number += 1;

        const words = try std.mem.split(u8, line, " ");

        switch (ParsingState) {
            .ExitSection => {
                current_section_type = words.next();
                i_parsing_state = ParsingState.SectionTypeGathered;
                i_parsing_section = ParsingSection.new();
                i_parsing_section.section_type_name = current_section_type;
            },
            .SectionTypeGathered => {
                const word = words.next();
                if (word[0] != SYMBOL_SECTION_BEGIN) {
                    return ErrorParsingJPP.ParsingError;
                }
                i_parsing_state = ParsingState.EnteredSection;
            },
            .EnteredSection => {
                var word = words.next();
                if (word[0] == SYMBOL_SECTION_END) {
                    // TODO: register section !
                    current_section_type = undefined;
                    i_parsing_state = ParsingState.ExitSection;
                    continue;
                }
                const property_name = word;
                word = words.next();
                if (word == SYMBOL_MULTILINE_TYPE) {
                    const format = words.next();
                    if (jpp_format.compare_str(format, jpp_format.SYMBOL_TYPE_VEC)) {
                        const raw_vector_len = word.next();
                        const vector_len = str.fmt.parseInt(u16, raw_vector_len, 10);
                        var property = ParsingProperty.new_vector(property_name, vector_len);
                        /// read more lines....

                    } else if (jpp_format.compare_str(format, jpp_format.SYMBOL_TYPE_MATRIX)) {

                    } else {
                        return ErrorParsingJPP.ParsingError;
                    }
                }
                const raw_property_value = word;
                const raw_property_value_last_char = raw_property_value[raw_property_value - 1];
                if (raw_property_value[0] == jpp_format.SYMBOL_STRING_DLEIMITER ) {
                    if ( raw_property_value_last_char != jpp_format.SYMBOL_STRING_DLEIMITER) {
                        return ErrorParsingJPP.ParsingError;
                    }
                    const property_value = raw_property_value[1 .. raw_property_value.len - 1];
                    var property = ParsingProperty.new_string(property_name, property_value);
                }
                else {
                    const property_value = try std.fmt.parseFloat(f32, raw_property_value); // FIXME: shall catch error and redirect a parsing error.
                    var property = ParsingProperty.new_number(property_name, property_value);
                }
            },
        }
    }
}

fn get_uncommented_line(str: []const u8) []const u8 {
    if (std.mem.indexOf(u8, str, SYMBOL_COMMENT)) |index| {
        return str[0..index];
    }
    return str;
}

// TODO: function to raise.


// fn _create_object(objet_type_as_str: []const u8) {
// }
//
