const types = @import("types.zig");
const color = @import("color.zig");

pub const Material = struct {
    diffuse: color.Color = color.COLOR_DEFAULT,
};

pub var MATERIAL_DEFAULT = Material{};
pub var MATERIAL_BASE_RED = Material{ .diffuse = color.COLOR_RED };
pub var MATERIAL_BASE_BLUE = Material{ .diffuse = color.COLOR_BLUE };
