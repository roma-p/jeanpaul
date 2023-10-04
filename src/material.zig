const types = @import("types.zig");

pub const COLOR_BlACK = types.Color{ .r = 0, .g = 0, .b = 0 };
pub const COLOR_WHITE = types.Color{ .r = 255, .g = 255, .b = 255 };
pub const COLOR_RED = types.Color{ .r = 255, .g = 0, .b = 0 };
pub const COLOR_GREEN = types.Color{ .r = 0, .g = 255, .b = 0 };
pub const COLOR_BLUE = types.Color{ .r = 0, .g = 0, .b = 255 };
pub const COLOR_GREY = types.Color{ .r = 100, .g = 100, .b = 100 };

pub const Material = struct {
    diffuse: types.Color = undefined,
};

pub const DEFAULT_COLOR = COLOR_GREY;
pub var DEFAULT_MATERIAL = Material{
    .diffuse = DEFAULT_COLOR,
};
