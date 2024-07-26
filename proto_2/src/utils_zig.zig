const std = @import("std");

pub fn compare_str(str1: []u8, str2: []u8) !bool {
    return std.mem.eql(u8, str1, str2);
}

pub fn cast_u16_to_f32(input: u16) f32 {
    // didn't find how to do this directly without casting as int first...
    // used mainly to go from screen space (2d u16 array) to 3d space (3d f32 array)
    const tmp: i32 = input;
    const ret: f32 = @floatFromInt(tmp);
    return ret;
}
