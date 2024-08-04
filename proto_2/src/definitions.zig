const maths_vec = @import("maths_vec.zig");
const data_color = @import("data_color.zig");

const Vec3f32 = maths_vec.Vec3f32;
const Color = data_color.Color;

pub const MaterialEnum = enum {
    Lambertian,
};

pub const ShapeEnum = enum {
    ImplicitSphere,
    ImplicitPlane,
};

pub const AovStandardEnum = enum {
    Beauty,
    Albedo,
    Alpha,
    Depth,
    Normal,
};

pub const Material = union(MaterialEnum) {
    Lambertian: struct {
        base: f32 = 0.7,
        base_color: Color = data_color.COLOR_GREY,
    },
};

pub const Shape = union(ShapeEnum) {
    ImplicitSphere: struct {
        radius: f32 = 10,
    },
    ImplicitPlane: struct {
        normal: Vec3f32 = Vec3f32.create_y(),
    },
};

// IDEA of api:
// add_shape("lul", Shape {.ImplicitSphere{}}, handleTMat or null, TMAT or null.
