const std = @import("std");
const jpp_format = @import("jpp_format.zig");
const jp_material = @import("jp_material.zig");

test "get_material_id_from_str_valid" {
    try std.testing.expectEqual(
        jpp_format.get_material_id_from_str("material.Lambert"),
        jp_material.MaterialTypeId.Lambert,
    );
}
