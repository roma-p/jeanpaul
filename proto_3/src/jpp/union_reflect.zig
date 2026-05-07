pub fn UnionReflect(comptime T: type) type {
    return struct {
        T: T,
        field_name_list: [][]const u8,
        field_type_list: []type,
        tag_start_end: []const usize,

        const Self = @This();

        pub fn init() Self {}

        // pub fn set_field(self: *Self, name: []const u8, value: []const u8) !void {
        // }
    };
}
