const std = @import("std");
const jp_object = @import("jp_object.zig");

const JpObjectCategory = jp_object.JpObjectCategory;

pub const SYMBOL_COMMENT = '#';
pub const SYMBOL_SECTION_BEGIN = '{';
pub const SYMBOL_SECTION_END = '}';
pub const SYMBOL_MULTILINE_TYPE = "!";
pub const SYMBOL_TYPE_VEC = "V";
pub const SYMBOL_TYPE_MATRIX = "M";

pub const STR_CAMERA_PERSP = "camera.persp";
pub const STR_IMPLICIT_SPHERE = "implicit.sphere";
pub const STR_LIGHT_OMNI = "light.omni";

pub fn type_id_to_shape_id(str: []u8) jp_object.ShapeTypeId {
    if (compare_str(str, STR_CAMERA_PERSP)) {
        return jp_object.ShapeTypeId.CameraPersp;
    } else if (compare_str(str, STR_IMPLICIT_SPHERE)) {
        return jp_object.ShapeTypeId.ImplicitSphere;
    } else if (compare_str(str, STR_LIGHT_OMNI)) {
        return jp_object.ShapeTypeId.LightOmni;
    } else {
        unreachable;
    }
}

pub fn shape_id_to_type_id(shape_type_id: jp_object.ShapeTypeId) []u8 {
    switch (shape_type_id) {
        .CameraPersp => return STR_CAMERA_PERSP,
        .ImplicitSphere => return STR_IMPLICIT_SPHERE,
        .LightOmni => return STR_LIGHT_OMNI,
    }
}

fn compare_str(str1: []u8, str2: []u8) !bool {
    return std.mem.eql(u8, str1, str2);
}
