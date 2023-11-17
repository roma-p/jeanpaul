const std = @import("std");
const jpp_format = @import("jpp_format.zig");
const jp_material = @import("jp_material.zig");
const jp_object = @import("jp_object.zig");

test "get_material_id_from_str_valid" {
    try std.testing.expectEqual(
        jpp_format.get_material_id_from_str("material.Lambert"),
        jp_material.MaterialTypeId.Lambert,
    );
}

test "get_object_id_from_str_valid" {
    try std.testing.expectEqual(
        jpp_format.get_shape_id_from_str("object.CameraPersp"),
        jp_object.ShapeTypeId.CameraPersp,
    );
}
