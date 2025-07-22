
const std = @import("std");
const mem = std.mem;

const UnionInfo = @This();

T: type,
field_name_list: [][]const u8,
field_type_list: []type,
tag_start_end: []const usize,

pub fn init(comptime T: type) UnionInfo {
}

pub fn set_field(union_info: *UnionInfo, t: union_info.T, name: []const u8, value: []const u8,) void {
    const idx = @intFromEnum(t);
    var i = union_info.tag_start_end[idx];
    const end = union_info.tag_start_end[idx + 1];
    
    var field_found: bool = false;
    while(i < end) : (i+=1) {
        if (mem.eql(u8, name, union_info.field_name_list[i])) {
            field_found = true;
            break;
        }
    }
    if (!field_found) return; // TODO raise error.

    const dest_type = union_info.field_type_list[i];
    const dst_value = switch (dest_type) {
        []const u8 => value,
        f32 => std.fmt.parseFloat(f32, value),
        else => unreachable,
    };
    
}
