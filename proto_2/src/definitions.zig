const maths_vec = @import("maths_vec.zig");
const data_color = @import("data_color.zig");

const Vec3f32 = maths_vec.Vec3f32;
const Color = data_color.Color;

pub const Material = struct {
    base: f32 = 0.7,
    base_color: Color = data_color.COLOR_GREY,
};

const Shape = union(ShapeEnum) {
    ImplicitSphere: struct {
        radius: f32 = 10,
    },
    ImplicitPlane: struct {
        normal: Vec3f32 = Vec3f32.create_y(),
    },
};

pub const ShapeEnum = enum {
    ImplicitSphere,
    ImplicitPlane,
};

pub const AovStandardEnum = enum {
    Beauty,
    Alpha,
    Depth,
    Normal,
};

// IDEA of api:
// add_shape("lul", Shape {.ImplicitSphere{}}, handleTMat or null, TMAT or null.
