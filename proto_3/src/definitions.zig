
pub const MaterialEnum = enum {
    Lambertian,
};

pub const Material = union(MaterialEnum) {
    Lambertian: struct {
        base: f32 = 0.7,
        // base_color: Color = data_color.COLOR_GREY,
        ambiant: f32 = 0.05,
    },
};

const MaterialTypeInfo = buildTypeMap(Material);

fn buildTypeMap(comptime T: type) struct {
    field_name_list: []const u8,
    field_type_list: []const u8,
    tag_start_end: []const usize,
} {
    const t_info = @typeInfo(T);
    const t_fields = t_info.Union.fields;

    var field_name_list: []const u8 = {};
    var field_type_list: []const u8 = {};
    // var tag_start_end:[]const usize = {0}usize ** (2 * t_fields.len);

    var idx: usize = 0;

    for (t_fields, 0..) |field, i| {

        _ = i;

        const f_info = @typeInfo(field);
        const f_fields = f_info.Struct.fields;

        field_name_list = field_name_list ++ [f_fields.len]"";
        field_type_list = field_type_list ++ [f_fields.len]"";

        for (f_fields) |tmp| {
            field_name_list[idx] = tmp.name;
            field_type_list[idx] = tmp.field_type;
            idx+= 1;
        }
    }

    return .{
        .field_name_list = field_name_list,
        .field_type_list = field_type_list,
        .tag_start_end = undefined,
    };
}

fn _buildTypeMap(comptime T: type) []const struct {
    tag_name: []const u8,
    struct_type: type,
} {
    const info = @typeInfo(T);
    const fields = info.Union.fields;

    var result: [fields.len]struct {
        tag_name: []const u8,
        struct_type: type,
    } = undefined;

    for (fields, 0..) |field, i| {
        result[i] = .{
            .tag_name = field.name,
            .struct_type = field.field_type,
        };
    }
    return result[0..];
}

