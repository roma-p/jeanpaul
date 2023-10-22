const std = @import("std");
const types = @import("types.zig");
const log = std.log;
const fs = std.fs;
const io = std.io;
const allocator = std.heap.page_allocator;
const jpp_format = @import("jpp_format.zig");
const zig_utils = @import("zig_utils.zig");
const jp_scene = @import("jp_scene.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");

const ShapeTypeId = jp_object.ShapeTypeId;
const MaterialTypeId = jp_material.MaterialTypeId;

pub const ErrorParsingJPP = error{
    ParsingError,
    ExpetedNumber,
    WrongType,
    MissingMandatoryValue,
};

// ==== PARSER ===============================================================

const ParsingState = enum {
    ParsingEntityType,
    ParsingSectionStart,
    ParsingSectionProperty,
    ParsingVector,
    ParsingMatrix,
};

pub const JppParser = struct {
    i_line: []const u8,
    i_line_number: u16,
    i_state: ParsingState,
    i_status: bool,
    i_current_section: *ParsingSection,
    i_current_property: *ParsingProperty,
    i_current_matrix_y_idx: u16,
    file_path: []const u8,
    parsing_section_list: std.ArrayList(*ParsingSection) = undefined,
    render_camera_name: []const u8,
    scene: *jp_scene.JpScene,

    const Self = @This();

    pub fn parse(file_path: []const u8) !*jp_scene.JpScene {

        // instiating self.
        var parsing_section_list = try std.ArrayList(
            *ParsingSection,
        ).initCapacity(allocator, 15);
        defer parsing_section_list.deinit();

        var self = try allocator.create(Self);
        defer allocator.destroy(self);

        self.* = Self{
            .i_line = undefined,
            .i_line_number = 0,
            .i_status = true,
            .i_state = ParsingState.ParsingEntityType,
            .i_current_section = undefined,
            .i_current_property = undefined,
            .i_current_matrix_y_idx = undefined,
            .file_path = file_path,
            .parsing_section_list = parsing_section_list,
            .render_camera_name = undefined,
            .scene = undefined,
        };

        // reading file.
        var file = try fs.cwd().openFile(file_path, .{});
        defer file.close();

        var buf: [1024]u8 = undefined;
        var stream = file.reader();

        // parsing lines.
        while (try stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (self.i_status == false) return ErrorParsingJPP.ParsingError;

            var _line = Self.get_uncommented_line(line);
            self.i_line_number += 1;
            if (_line.len == 0) continue;
            self.i_line = _line;

            switch (self.i_state) {
                .ParsingEntityType => try self.state_ParsingEntityType(),
                .ParsingSectionStart => try self.state_ParsingSectionStart(),
                .ParsingSectionProperty => try self.state_ParsingSectionProperty(),
                .ParsingVector => try self.state_ParsingVector(),
                .ParsingMatrix => try self.state_ParsingMatrix(),
                // else => {},
            }
        }
        try self.parsing_section_list.append(self.i_current_section);
        // FIXME: DESTROY PARSING SECTION LIST!!

        // first iteration on parsing section -> looking for scene definition.
        var scene_found = false;
        for (self.parsing_section_list.items) |section| {
            // section.print_debug();
            if (std.mem.eql(u8, section.section_type_name, "scene")) {
                scene_found = true;
                self.scene = try self.build_scene(section);
            }
        }
        if (!scene_found) {
            JppParser.log_build_error_missing_section("scene");
            return ErrorParsingJPP.MissingMandatoryValue;
        }
        return self.scene;
    }

    // ---- STATES -----------------------------------------------------------

    // ==> ParsingEntityType -------------------------------------------------
    fn state_ParsingEntityType(self: *Self) !void {
        var words = std.mem.split(u8, self.i_line, " ");

        const current_section_name = words.next() orelse {
            var err_str = "expecting section name definition, find nothing.";
            self.exit_state_in_err(err_str);
            return;
        };

        if (words.next() != null) {
            var err_str = "expecting section name definition (one word)";
            self.exit_state_in_err(err_str);
            return;
        }

        const is_name_correct = try self.check_name_correct(current_section_name);
        if (is_name_correct == false) {
            return;
        }
        self.i_current_section = try ParsingSection.new(
            current_section_name,
            self.i_line_number,
        );
        self.i_state = ParsingState.ParsingSectionStart;
    }

    // ==> ParsingSectionStart -----------------------------------------------
    fn state_ParsingSectionStart(self: *Self) !void {
        if (!std.mem.eql(u8, self.i_line, jpp_format.SYMBOL_SECTION_BEGIN)) {
            var err_str = try std.fmt.allocPrint(
                allocator,
                "expected section delimiter '{s}', got: '{s}'.",
                .{ jpp_format.SYMBOL_SECTION_BEGIN, self.i_line },
            );
            defer allocator.free(err_str);
            self.exit_state_in_err(err_str);
            return; //FIXME: not sure...
        }
        self.i_state = ParsingState.ParsingSectionProperty;
    }

    // ==> ParsingSectionProperty --------------------------------------------
    fn state_ParsingSectionProperty(self: *Self) !void {
        // 1 => if section definition finished
        if (std.mem.eql(u8, self.i_line, jpp_format.SYMBOL_SECTION_END)) {
            try self.parsing_section_list.append(self.i_current_section);
            self.i_state = ParsingState.ParsingEntityType;
            return;
        }

        // 2 => getting property name, property value.
        var words = std.mem.split(u8, self.i_line, " ");
        const property_name = words.next() orelse return;

        const is_name_correct = try self.check_name_correct(property_name);
        if (is_name_correct == false) {
            return;
        }

        const second_word = words.next() orelse {
            var err_str = "expecting property value, find nothing";
            self.exit_state_in_err(err_str);
            return;
        };

        // 3 => porperty value is multiline.
        if (std.mem.eql(u8, second_word, jpp_format.SYMBOL_MULTILINE_TYPE)) {
            const type_symbol = words.next() orelse {
                var err_str = "expecting type definition symbol, find nothing";
                self.exit_state_in_err(err_str);
                return;
            };
            // 3.1 => is vector
            if (std.mem.eql(u8, type_symbol, jpp_format.SYMBOL_TYPE_VEC)) {
                const vector_size = words.next();
                self.parsing_vector_header(property_name, vector_size) orelse return;
                return;
            }
            // 3.2 => is matrix
            if (std.mem.eql(u8, type_symbol, jpp_format.SYMBOL_TYPE_MATRIX)) {
                const vector_x_size = words.next();
                const vector_y_size = words.next();
                self.i_current_matrix_y_idx = 0;
                self.parsing_matrix_header(
                    property_name,
                    vector_x_size,
                    vector_y_size,
                ) orelse return;
            }
            return;
        }

        // 4 => property value is single line.
        // 4.1 => second word is a string.
        if (second_word[0] == jpp_format.SYMBOL_STRING_DELIMITER) {
            if (second_word[second_word.len - 1] != jpp_format.SYMBOL_STRING_DELIMITER) {
                var err_str = try std.fmt.allocPrint(
                    allocator,
                    "Missing ending string delimiter: {s}",
                    .{second_word},
                );
                defer allocator.free(err_str);
                self.exit_state_in_err(err_str);
            }
            const property_value = second_word[1 .. second_word.len - 1];
            self.i_current_property = try ParsingProperty.new_string(
                property_name,
                property_value,
                self.i_line_number,
            );
            try self.i_current_section.property_list.append(self.i_current_property);
            return;
        }
        // 4.2 => second word is a string.
        const property_value = try self.conv_word_to_f32(second_word) orelse return;
        self.i_current_property = try ParsingProperty.new_number(
            property_name,
            property_value,
            self.i_line_number,
        );
        try self.i_current_section.property_list.append(self.i_current_property);
    }

    // ==> ParsingVector -----------------------------------------------------
    fn state_ParsingVector(self: *Self) !void {
        var i: u16 = 0;
        var words = std.mem.split(u8, self.i_line, " ");
        const size = self.i_current_property.value.Vector.size;
        while (i < size) : (i += 1) {
            const number = try self.conv_word_to_f32(words.next()) orelse return;
            self.i_current_property.value.Vector.vector[i] = number;
        }
        if (words.next() != null) {
            var err_str = try std.fmt.allocPrint(
                allocator,
                "expecting vector of size {d}, but find bigger one.",
                .{size},
            );
            defer allocator.free(err_str);
            self.exit_state_in_err(err_str);
        }
        self.i_state = ParsingState.ParsingSectionProperty;
        try self.i_current_section.property_list.append(self.i_current_property);
    }

    // ==> ParsingVector -----------------------------------------------------
    fn state_ParsingMatrix(self: *Self) !void {
        var words = std.mem.split(u8, self.i_line, " ");
        const x_max = self.i_current_property.value.Matrix.x_size;
        const y_current = self.i_current_matrix_y_idx;

        var x_current: u16 = 0;
        while (x_current < x_max) : (x_current += 1) {
            const number = try self.conv_word_to_f32(words.next()) orelse return;
            self.i_current_property.value.Matrix.matrix[x_current][y_current] = number;
        }
        if (words.next() != null) {
            var err_str = try std.fmt.allocPrint(
                allocator,
                "expecting matrix of x size {d}, but find bigger one.",
                .{x_current},
            );
            defer allocator.free(err_str);
            self.exit_state_in_err(err_str);
        }
        self.i_current_matrix_y_idx += 1;
        if (y_current < self.i_current_property.value.Matrix.y_size - 1) return;

        self.i_state = ParsingState.ParsingSectionProperty;
        try self.i_current_section.property_list.append(self.i_current_property);
    }

    fn parsing_vector_header(
        self: *Self,
        property_name: []const u8,
        size_as_str: ?[]const u8,
    ) ?void {
        const size = self.conv_word_to_u16(size_as_str) catch return null;
        self.i_state = ParsingState.ParsingVector;
        self.i_current_property = ParsingProperty.new_vector(
            property_name,
            size orelse 0,
            self.i_line_number,
        ) catch return null;
    }

    fn parsing_matrix_header(
        self: *Self,
        property_name: []const u8,
        x_size_as_str: ?[]const u8,
        y_size_as_str: ?[]const u8,
    ) ?void {
        const x_size = self.conv_word_to_u16(x_size_as_str) catch return null;
        const y_size = self.conv_word_to_u16(y_size_as_str) catch return null;

        self.i_state = ParsingState.ParsingMatrix;
        self.i_current_property = ParsingProperty.new_matrix(
            property_name,
            x_size orelse 0,
            y_size orelse 0,
            self.i_line_number,
        ) catch return null;
        return;
    }

    fn exit_state_in_err(self: *Self, mess: []const u8) void {
        std.log.err("Error parsing file: {s} at line {d}\n", .{
            self.file_path,
            self.i_line_number,
        });
        std.log.err(" -> {s}\n", .{mess});
        self.i_status = false;
    }

    // ---- PARSING HELPERS --------------------------------------------------

    fn check_name_correct(self: *Self, name: []const u8) !bool {
        if (name.len == 0) {
            self.exit_state_in_err("expecting string, find nothing");
            return false;
        }
        const ret = std.ascii.isAlphabetic(name[0]);
        if (ret == false) {
            var err_str = try std.fmt.allocPrint(
                allocator,
                "invalid name: '{s}', name cannot start with number",
                .{name},
            );
            defer allocator.free(err_str);
            self.exit_state_in_err(err_str);
        }
        return ret;
    }

    fn get_uncommented_line(line: []u8) []const u8 {
        if (std.mem.indexOf(u8, line, jpp_format.SYMBOL_COMMENT)) |index| {
            return line[0..index];
        }
        return line;
    }

    fn conv_word_to_u16(self: *Self, word: ?[]const u8) !?u16 {
        const non_null_word = word orelse {
            var err_str = "expecting integer, find nothing";
            self.exit_state_in_err(err_str);
            return null;
        };
        const ret = std.fmt.parseInt(u16, non_null_word, 10) catch {
            var err_str = try std.fmt.allocPrint(
                allocator,
                "expecting integer, find '{s}'",
                .{non_null_word},
            );
            defer allocator.free(err_str);
            self.exit_state_in_err(err_str);
            return null;
        };
        return ret;
    }

    fn conv_word_to_f32(self: *Self, word: ?[]const u8) !?f32 {
        const non_null_word = word orelse {
            var err_str = "expecting float, find nothing";
            self.exit_state_in_err(err_str);
            return null;
        };
        const ret = std.fmt.parseFloat(f32, non_null_word) catch {
            var err_str = try std.fmt.allocPrint(
                allocator,
                "expecting float, find '{s}'",
                .{non_null_word},
            );
            defer allocator.free(err_str);
            self.exit_state_in_err(err_str);
            return null;
        };
        return ret;
    }

    // ---- BUILDING SCENE ---------------------------------------------------

    pub fn build_scene(
        self: *Self,
        parsed_section: *ParsingSection,
    ) !*jp_scene.JpScene {
        var render_camera_defined = false;
        var resolution_found = false;

        var scene = try jp_scene.JpScene.new();
        // errdefer scene.delete(); FIXME:

        for (parsed_section.property_list.items) |property| {
            if (std.mem.eql(u8, property.name, "render_camera")) {
                render_camera_defined = true;
                switch (property.value.*) {
                    .String => self.render_camera_name = property.value.String,
                    else => {
                        try JppParser.log_build_error_wrong_type(
                            property.name,
                            "str",
                            property.line,
                        );
                        return ErrorParsingJPP.WrongType;
                    },
                }
            }
            if (std.mem.eql(u8, property.name, "resolution")) {
                resolution_found = true;
                var valid_type = true;
                switch (property.value.*) {
                    .Vector => {},
                    else => {
                        valid_type = false;
                    },
                }
                if (valid_type and property.value.Vector.size != 2) {
                    valid_type = false;
                }
                if (!valid_type) {
                    try JppParser.log_build_error_wrong_type(
                        property.name,
                        "vector size 2",
                        property.line,
                    );
                    return ErrorParsingJPP.WrongType;
                }
                scene.resolution = types.Vec2u16{
                    .x = @intFromFloat(property.value.Vector.vector[0]),
                    .y = @intFromFloat(property.value.Vector.vector[1]),
                };
            }
        }
        if (!render_camera_defined) {
            try JppParser.log_build_error_missing("render_camera", parsed_section.line);
            return ErrorParsingJPP.MissingMandatoryValue;
        }
        if (!resolution_found) {
            try JppParser.log_build_error_missing("resolution", parsed_section.line);
            return ErrorParsingJPP.MissingMandatoryValue;
        }
        parsed_section.processed = true;
        return scene;
    }

    pub fn build_material(
        parsed_section: *ParsingSection,
        material_type: MaterialTypeId,
    ) ErrorParsingJPP!*jp_material.JpMaterial {
        var name_found = false;
        var material = jp_material.JpMaterial.new(material_type);
        errdefer material.delete();
        for (parsed_section.property_list.items()) |property| {
            if (std.mem.eql(u8, property.name, "name")) {
                name_found = true;
                switch (property.value) {
                    .String => material.name = property.value,
                    else => {
                        JppParser.log_build_error(
                            property.line,
                            "'name' is expected to be a string",
                        );
                        return ErrorParsingJPP.WrongType;
                    },
                }
            }
        }
        if (!name_found) {
            JppParser.log_build_error(
                parsed_section.line,
                "expected 'name' property, not found",
            );
            return ErrorParsingJPP.MissingMandatoryValue;
        }
    }

    // fn build_lambert(parsed_section: *ParsingSection, material:

    pub fn build_object(
        parsed_section: *ParsingSection,
        shape_type: ShapeTypeId,
    ) ErrorParsingJPP!*jp_scene.JpScene {
        var name_found = false;
        var object = jp_object.JpObject.new(shape_type);
        errdefer object.delete();
        for (parsed_section.property_list.items()) |property| {
            if (std.mem.eql(u8, property.name, "name")) {
                name_found = true;
                switch (property.value) {
                    .String => object.name = property.value,
                    else => {
                        //TODO : log
                        return ErrorParsingJPP.MissingMandatoryValue;
                    },
                }
            } else if (std.mem.eql(u8, property.name, "tmatrix")) {
                switch (property.value) {
                    .Matrix => {
                        if (property.value.Matrix.x_size != 4 or
                            property.value.Matrix.y_size != 4)
                        {
                            //TODO: log.
                            return ErrorParsingJPP.ErrorParsingJPP;
                        }
                    },
                    else => {
                        // TODO log
                        return ErrorParsingJPP.WrongType;
                    },
                }
                var i: usize = 0;
                var j: usize = 0;
                while (i < 4) : (i += 1) {
                    while (j < 4) : (j += 1) {
                        object.tmatrix.m[i][j] = property.value.Matrix.matrix[i][j];
                    }
                }
            }
        }
        if (!name_found) {
            //TODO: log.
            return ErrorParsingJPP.MissingMandatoryValue;
        }
        // TODO: SHAPE BUILDER...
        switch (shape_type) {
            .ImplicitSphere => {},
            .CameraPersp => {},
            .LightOmni => {},
        }
    }

    fn log_build_error_missing_section(section_name: []const u8) void {
        std.log.err("missing mandatory section: {s}", .{section_name});
    }

    fn log_build_error_missing(section_name: []const u8, line: u16) !void {
        const err_str = try std.fmt.allocPrint(
            allocator,
            "missing mandatory property: {s}",
            .{section_name},
        );
        defer allocator.free(err_str);
        JppParser.log_build_error(err_str, line);
    }

    fn log_build_error_wrong_type(
        property_name: []const u8,
        expected_type_as_str: []const u8,
        line: u16,
    ) !void {
        const err_str = try std.fmt.allocPrint(
            allocator,
            "wong type for property '{s}', expected type is: {s}",
            .{ property_name, expected_type_as_str },
        );
        defer allocator.free(err_str);
        JppParser.log_build_error(err_str, line);
    }

    fn log_build_error(mess: []const u8, line: u16) void {
        std.log.err("line {d} : {s}.", .{ line, mess });
    }
};

// ==== PARSING SECTION DTO ==================================================

const ParsingSection = struct {
    section_type_name: []const u8 = undefined,
    property_list: std.ArrayList(*ParsingProperty) = undefined,
    line: u16 = undefined,
    processed: bool = false,

    const Self = @This();

    pub fn new(section_type_name: []const u8, line: u16) !*Self {
        var instance = try allocator.create(Self);
        const copied = try allocator.alloc(u8, section_type_name.len); // ?? why is this needed?
        std.mem.copy(u8, copied, section_type_name);
        instance.* = Self{
            .section_type_name = copied,
            .property_list = try std.ArrayList(
                *ParsingProperty,
            ).initCapacity(allocator, 5),
            .line = line,
        };
        return instance;
    }

    pub fn delete(self: *Self) void {
        // FIXME: delete properties !!!!
        allocator.free(self.section_type_name);
        self.property_list.deinit();
        allocator.destroy(self);
    }

    pub fn print_debug(self: *Self) void {
        std.debug.print("\n{s}\n", .{self.section_type_name});
        for (self.property_list.items) |property| {
            switch (property.value.*) {
                .String => {
                    std.debug.print("    - {s} (string): {s}\n", .{ property.name, property.value.String });
                },
                .Number => {
                    std.debug.print("    - {s} (number): {d}\n", .{ property.name, property.value.Number });
                },
                .Vector => {
                    std.debug.print("    - {s} (vector).\n", .{property.name});
                },
                .Matrix => {
                    std.debug.print("    - {s} (matrix).\n", .{property.name});
                },
            }
        }
        std.debug.print("\n", .{});
    }
};

const ParsingProperty = struct {
    name: []const u8,
    value: *ParsingPropertyValue,
    line: u16 = undefined,

    const Self = @This();

    pub fn new_number(name: []const u8, number: f32, line: u16) !*Self {
        var instance = try Self._new(name, line);
        instance.value.* = ParsingPropertyValue{ .Number = number };
        return instance;
    }

    pub fn new_string(name: []const u8, string: []const u8, line: u16) !*Self {
        const copied = try allocator.alloc(u8, string.len); // ?? why is this needed?
        std.mem.copy(u8, copied, string);
        var instance = try Self._new(name, line);
        instance.value.* = ParsingPropertyValue{ .String = copied };
        return instance;
    }

    pub fn new_matrix(name: []const u8, x_size: u16, y_size: u16, line: u16) !*Self {
        var instance = try Self._new(name, line);
        instance.value.* = ParsingPropertyValue{
            .Matrix = try ParsingPropertyMatrix.new(x_size, y_size),
        };
        return instance;
    }

    pub fn new_vector(name: []const u8, size: u16, line: u16) !*Self {
        var instance = try Self._new(name, line);
        var vec: *ParsingPropertyVector = try ParsingPropertyVector.new(size);
        instance.value.* = ParsingPropertyValue{ .Vector = vec };
        return instance;
    }

    fn _new(name: []const u8, line: u16) !*Self {
        const copied = try allocator.alloc(u8, name.len); // ?? why is this needed?
        std.mem.copy(u8, copied, name);

        var instance = try allocator.create(Self);
        var value = try allocator.create(ParsingPropertyValue);
        instance.* = Self{ .name = copied, .value = value, .line = line };
        return instance;
    }

    pub fn delete(self: *Self) void {
        switch (self.value) {
            .Matrix => self.value.Matrix.delete(),
            .Vector => self.value.Vector.delete(),
            .String => allocator.free(self.value.String),
            else => {},
        }
        allocator.free(self.name);
        allocator.destroy(self.value);
        allocator.destroy(self);
    }
};

const ParsingPropertyValue = union(enum) {
    Number: f32,
    String: []const u8,
    Matrix: *ParsingPropertyMatrix,
    Vector: *ParsingPropertyVector,
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
            .matrix = try types.matrix_f32_create(x_size, y_size),
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
            .vector = try types.vector_f32_create(size),
        };
        return instance;
    }

    pub fn delete(self: *Self) void {
        types.vector_f32_delete(self.vector);
        allocator.destroy(self);
    }
};
