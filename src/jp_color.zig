pub const JpColor = struct {
    r: u8 = undefined,
    g: u8 = undefined,
    b: u8 = undefined,
};

pub const JP_COLOR_BlACK = JpColor{ .r = 0, .g = 0, .b = 0 };
pub const JP_COLOR_WHITE = JpColor{ .r = 255, .g = 255, .b = 255 };
pub const JP_COLOR_RED = JpColor{ .r = 255, .g = 0, .b = 0 };
pub const JP_COLOR_GREEN = JpColor{ .r = 0, .g = 255, .b = 0 };
pub const JP_COLOR_BLUE = JpColor{ .r = 0, .g = 0, .b = 255 };
pub const JP_COLOR_GREY = JpColor{ .r = 100, .g = 100, .b = 100 };

pub const JP_COLOR_DEFAULT = JP_COLOR_GREY;
