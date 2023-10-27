const std = @import("std");
const types = @import("types.zig");

test "multiply_with_vec3" {
    var tmatrix = try types.TMatrixf32.new();
    var position_1 = types.Vec3f32{
        .x = 1,
        .y = 2,
        .z = 3,
    };
    var position_2 = types.Vec3f32{
        .x = 4,
        .y = 5,
        .z = 6,
    };
    try tmatrix.set_position(&position_1);
    const vec = tmatrix.multiply_with_vec3(&position_2);
    vec.log_debug();
}
