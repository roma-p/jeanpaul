const types = @import("types.zig");
const color = @import("color.zig");

pub const Material = struct {
    diffuse: color.Color = color.COLOR_DEFAULT,
};

pub var MATERIAL_DEFAULT = Material{};
