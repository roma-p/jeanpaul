const std = @import("std");

const Value = union(enum) {
    int: i64,
    uint: u64,
    float: f64,
    boolean: bool,
    string: []const u8,
    enum_tag: []const u8, // Store enum as string tag name

    pub fn as(self: Value, comptime T: type) !T {
        const type_info = @typeInfo(T);

        return switch (type_info) {
            .int => |int_info| {
                if (int_info.signedness == .signed) {
                    // Signed integers
                    switch (self) {
                        .int => |v| return @intCast(v),
                        .uint => |v| return @intCast(v),
                        .float => |v| return @intFromFloat(v),
                        else => return error.TypeMismatch,
                    }
                } else {
                    // Unsigned integers (like u32)
                    switch (self) {
                        .uint => |v| return @intCast(v),
                        .int => |v| {
                            if (v < 0) return error.NegativeToUnsigned;
                            return @intCast(v);
                        },
                        .float => |v| {
                            if (v < 0) return error.NegativeToUnsigned;
                            return @intFromFloat(v);
                        },
                        else => return error.TypeMismatch,
                    }
                }
            },
            .float => {
                switch (self) {
                    .float => |v| return @floatCast(v),
                    .int => |v| return @floatFromInt(v),
                    .uint => |v| return @floatFromInt(v),
                    else => return error.TypeMismatch,
                }
            },
            .bool => {
                switch (self) {
                    .boolean => |v| return v,
                    .int => |v| return v != 0,
                    .uint => |v| return v != 0,
                    else => return error.TypeMismatch,
                }
            },
            .pointer => |ptr_info| {
                if (ptr_info.size == .slice and ptr_info.child == u8) {
                    // Handle []const u8 and []u8
                    switch (self) {
                        .string => |v| return v,
                        else => return error.TypeMismatch,
                    }
                } else {
                    return error.UnsupportedType;
                }
            },
            .@"enum" => |enum_info| {
                // Get the tag type of the enum (the underlying integer type)
                const TagType = enum_info.tag_type;

                switch (self) {
                    .enum_tag => |tag_name| {
                        // Find the enum field that matches the tag name
                        inline for (enum_info.fields) |field| {
                            if (std.mem.eql(u8, field.name, tag_name)) {
                                return @enumFromInt(@as(TagType, @intCast(field.value)));
                            }
                        }
                        return error.InvalidEnumTag;
                    },
                    .string => |tag_name| {
                        // Also accept string as enum tag
                        inline for (enum_info.fields) |field| {
                            if (std.mem.eql(u8, field.name, tag_name)) {
                                return @enumFromInt(@as(TagType, @intCast(field.value)));
                            }
                        }
                        return error.InvalidEnumTag;
                    },
                    .int => |v| {
                        // Allow setting enum by integer value
                        return @enumFromInt(@as(TagType, @intCast(v)));
                    },
                    .uint => |v| {
                        // Allow setting enum by integer value
                        return @enumFromInt(@as(TagType, @intCast(v)));
                    },
                    else => return error.TypeMismatch,
                }
            },
            else => return error.UnsupportedType,
        };
    }

    // Helper function to create enum value from tag name
    pub fn enumTag(tag_name: []const u8) Value {
        return Value{ .enum_tag = tag_name };
    }

    // Helper function to create enum value from any enum
    pub fn fromEnum(enum_value: anytype) Value {
        const tag_name = @tagName(enum_value);
        return Value{ .enum_tag = tag_name };
    }
};

fn StructSetter(comptime T: type) type {
    const type_info = @typeInfo(T);
    if (type_info != .@"struct") @compileError("Expected struct type");

    return struct {
        pub fn set(instance: *T, field_name: []const u8, value: Value) !void {
            inline for (type_info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    @field(instance, field.name) = try value.as(field.type);
                    return;
                }
            }
            return error.FieldNotFound;
        }

        pub fn hasField(field_name: []const u8) bool {
            inline for (type_info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return true;
                }
            }
            return false;
        }

        pub fn getFieldType(field_name: []const u8) ?type {
            inline for (type_info.@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return field.type;
                }
            }
            return null;
        }
    };
}

fn UnionSetter(comptime T: type) type {
    const type_info = @typeInfo(T);
    if (type_info != .@"union") @compileError("Expected union type");

    return struct {
        pub fn set(instance: *T, field_name: []const u8, value: Value) !void {
            inline for (type_info.@"union".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    const converted_value = try value.as(field.type);
                    instance.* = @unionInit(T, field.name, converted_value);
                    return;
                }
            }
            return error.FieldNotFound;
        }

        pub fn getActiveField(instance: T) ?[]const u8 {
            if (type_info.@"union".tag_type == null) return null;

            const tag = std.meta.activeTag(instance);
            return @tagName(tag);
        }

        pub fn hasField(field_name: []const u8) bool {
            inline for (type_info.@"union".fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return true;
                }
            }
            return false;
        }

        pub fn isTagged() bool {
            return type_info.@"union".tag_type != null;
        }
    };
}

fn GenericSetter(comptime T: type) type {
    const type_info = @typeInfo(T);

    return struct {
        pub fn set(instance: *T, field_name: []const u8, value: Value) !void {
            switch (type_info) {
                .@"struct" => |struct_info| {
                    inline for (struct_info.fields) |field| {
                        if (std.mem.eql(u8, field.name, field_name)) {
                            @field(instance, field.name) = try value.as(field.type);
                            return;
                        }
                    }
                },
                .@"union" => |union_info| {
                    inline for (union_info.fields) |field| {
                        if (std.mem.eql(u8, field.name, field_name)) {
                            const converted_value = try value.as(field.type);
                            instance.* = @unionInit(T, field.name, converted_value);
                            return;
                        }
                    }
                },
                else => return error.UnsupportedType,
            }
            return error.FieldNotFound;
        }
    };
}

// Test types
const Status = enum {
    inactive,
    active,
    pending,
    suspended,
};

const Priority = enum(u8) {
    low = 1,
    medium = 5,
    high = 10,
    critical = 20,
};

const MyStruct = struct {
    name: []const u8,
    age: u32,
    active: bool,
    status: Status,
    priority: Priority,
};

const MyUnion = union(enum) {
    text: []const u8,
    number: i32,
    flag: bool,
    status: Status,
    priority: Priority,
};

test "struct setter with enums" {
    var my_struct = MyStruct{
        .name = "initial",
        .age = 0,
        .active = false,
        .status = .inactive,
        .priority = .low,
    };

    const Setter = StructSetter(MyStruct);

    try Setter.set(&my_struct, "age", Value{ .uint = 25 });
    try Setter.set(&my_struct, "active", Value{ .boolean = true });
    try Setter.set(&my_struct, "name", Value{ .string = "updated" });
    try Setter.set(&my_struct, "status", Value.enumTag("active"));
    try Setter.set(&my_struct, "priority", Value{ .string = "high" });

    try std.testing.expect(my_struct.age == 25);
    try std.testing.expect(my_struct.active == true);
    try std.testing.expect(std.mem.eql(u8, my_struct.name, "updated"));
    try std.testing.expect(my_struct.status == .active);
    try std.testing.expect(my_struct.priority == .high);
}

test "union setter with enums" {
    var my_union = MyUnion{ .text = "initial" };

    const Setter = UnionSetter(MyUnion);

    try Setter.set(&my_union, "number", Value{ .int = 42 });
    try std.testing.expect(my_union.number == 42);

    try Setter.set(&my_union, "status", Value.enumTag("pending"));
    try std.testing.expect(my_union.status == .pending);

    try Setter.set(&my_union, "priority", Value{ .int = 20 }); // Set by integer value
    try std.testing.expect(my_union.priority == .critical);

    try std.testing.expect(std.mem.eql(u8, Setter.getActiveField(my_union).?, "priority"));
}

test "generic setter with enums" {
    var my_struct = MyStruct{
        .name = "initial",
        .age = 0,
        .active = false,
        .status = .inactive,
        .priority = .low,
    };
    var my_union = MyUnion{ .text = "initial" };

    const StructGenSetter = GenericSetter(MyStruct);
    const UnionGenSetter = GenericSetter(MyUnion);

    try StructGenSetter.set(&my_struct, "status", Value.enumTag("suspended"));
    try UnionGenSetter.set(&my_union, "status", Value{ .string = "active" });

    try std.testing.expect(my_struct.status == .suspended);
    try std.testing.expect(my_union.status == .active);
}

test "enum type conversions" {
    // Test various enum conversion methods
    const enum_tag_val = Value.enumTag("active");
    const string_high_val = Value{ .string = "high" };
    const string_medium_val = Value{ .string = "medium" };
    const int_val = Value{ .int = 5 }; // 5 corresponds to Priority.medium
    const int_high_val = Value{ .int = 10 }; // 10 corresponds to Priority.high
    const from_enum_val = Value.fromEnum(Status.pending);

    try std.testing.expect(try enum_tag_val.as(Status) == .active);
    try std.testing.expect(try string_high_val.as(Priority) == .high);
    try std.testing.expect(try string_medium_val.as(Priority) == .medium);
    try std.testing.expect(try int_val.as(Priority) == .medium); // 5 -> .medium
    try std.testing.expect(try int_high_val.as(Priority) == .high); // 10 -> .high
    try std.testing.expect(try from_enum_val.as(Status) == .pending);

    // Test error cases
    const invalid_tag = Value.enumTag("nonexistent");
    try std.testing.expectError(error.InvalidEnumTag, invalid_tag.as(Status));
}

test "all type conversions" {
    // Test various type conversions including enums
    const uint_val = Value{ .uint = 42 };
    const int_val = Value{ .int = -10 };
    const float_val = Value{ .float = 3.14 };
    const bool_val = Value{ .boolean = true };
    const enum_val = Value.enumTag("critical");

    try std.testing.expect(try uint_val.as(u32) == 42);
    try std.testing.expect(try uint_val.as(i32) == 42);
    try std.testing.expect(try int_val.as(i32) == -10);
    try std.testing.expect(try float_val.as(f32) == 3.14);
    try std.testing.expect(try bool_val.as(bool) == true);
    try std.testing.expect(try enum_val.as(Priority) == .critical);

    // Test error cases
    try std.testing.expectError(error.NegativeToUnsigned, int_val.as(u32));
}
