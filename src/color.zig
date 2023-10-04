pub const Color = struct {
    r: u8 = undefined,
    g: u8 = undefined,
    b: u8 = undefined,
};

pub const COLOR_BlACK = Color{ .r = 0, .g = 0, .b = 0 };
pub const COLOR_WHITE = Color{ .r = 255, .g = 255, .b = 255 };
pub const COLOR_RED = Color{ .r = 255, .g = 0, .b = 0 };
pub const COLOR_GREEN = Color{ .r = 0, .g = 255, .b = 0 };
pub const COLOR_BLUE = Color{ .r = 0, .g = 0, .b = 255 };
pub const COLOR_GREY = Color{ .r = 100, .g = 100, .b = 100 };

pub const COLOR_DEFAULT = COLOR_GREY;
