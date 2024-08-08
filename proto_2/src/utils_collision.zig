const constants = @import("constants.zig");
const maths_vec = @import("maths_vec.zig");
const maths = @import("maths.zig");

pub const HitResult = struct {
    hit: u1,
    t: f32,
};
