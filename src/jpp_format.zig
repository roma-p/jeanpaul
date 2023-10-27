const std = @import("std");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");

const ShapeTypeId = jp_object.ShapeTypeId;
const JpObjectCategory = jp_object.JpObjectCategory;
const MaterialTypeId = jp_material.MaterialTypeId;

pub const SYMBOL_COMMENT = "#";
pub const SYMBOL_SECTION_BEGIN = "{";
pub const SYMBOL_STRING_DELIMITER = '"';
pub const SYMBOL_SECTION_END = "}";
pub const SYMBOL_MULTILINE_TYPE = "!";
pub const SYMBOL_TYPE_VEC = "V";
pub const SYMBOL_TYPE_MATRIX = "M";

// TODO: DEL ME!
pub const STR_CAMERA_PERSP = "camera.persp";
pub const STR_IMPLICIT_SPHERE = "implicit.sphere";
pub const STR_LIGHT_OMNI = "light.omni";

pub const STR_ID_OBJECT = "object";
pub const STR_ID_MATERIAL = "material";
pub const STR_ID_SCENE = "scene";

pub const TypeNotFound = error{
    ShapeTypeNotFound,
    NotShapeType,
    NotMaterialType,
    MaterialTypeNotFound,
};

// OBJECT HELPERS ------------------------------------------------------------

pub fn get_shape_id_from_str(str: []const u8) !ShapeTypeId {
    if (str.len + 1 < STR_ID_OBJECT.len) {
        return TypeNotFound.NotShapeType;
    }
    if (!std.mem.eql(u8, str[0 .. STR_ID_OBJECT.len + 1], STR_ID_OBJECT ++ ".")) {
        return TypeNotFound.NotShapeType;
    }
    const shape_type = str[STR_ID_OBJECT.len + 1 .. str.len];

    for (jp_object.ShapeTypeIdArray) |i_shape_type| {
        if (std.mem.eql(u8, shape_type, @tagName(i_shape_type))) {
            return i_shape_type;
        }
    }
    return TypeNotFound.ShapeTypeNotFound;
}

pub fn get_str_from_shape_id(shape_type: ShapeTypeId) []u8 {
    //FIXME: missing "material."
    return @tagName(shape_type);
}

// MATERIAL HELPERS ----------------------------------------------------------

pub fn get_material_id_from_str(str: []const u8) TypeNotFound!MaterialTypeId {
    if (str.len + 1 < STR_ID_MATERIAL.len) {
        return TypeNotFound.NotMaterialType;
    }
    if (!std.mem.eql(u8, str[0 .. STR_ID_MATERIAL.len + 1], STR_ID_MATERIAL ++ ".")) {
        return TypeNotFound.NotMaterialType;
    }
    const mat_type = str[STR_ID_MATERIAL.len + 1 .. str.len];

    for (jp_material.MaterialTypeIdArray) |i_mat_type| {
        if (std.mem.eql(u8, mat_type, @tagName(i_mat_type))) {
            return MaterialTypeId.Lambert;
        }
    }
    return TypeNotFound.MaterialTypeNotFound;
}

pub fn get_str_from_material_id(material_type: MaterialTypeId) []u8 {
    //FIXME: missing "material."
    return STR_ID_MATERIAL ++ "." ++ @tagName(material_type);
}
