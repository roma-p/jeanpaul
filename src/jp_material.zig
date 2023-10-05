const types = @import("types.zig");
const jp_color = @import("jp_color.zig");

pub const JpMaterial = struct {
    diffuse: jp_color.JpColor = jp_color.JP_COLOR_DEFAULT,
};

pub var JP_MATERIAL_DEFAULT = JpMaterial{};
pub var JP_MATERIAL_BASE_RED = JpMaterial{ .diffuse = jp_color.JP_COLOR_RED };
pub var JP_MATERIAL_BASE_BLUE = JpMaterial{ .diffuse = jp_color.JP_COLOR_BLUE };
