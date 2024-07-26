const std = @import("std");

// values are betwen 0 and 1.
pub const Color = struct {
    r: f32 = undefined,
    g: f32 = undefined,
    b: f32 = undefined,

    pub fn multiply(self: *const Color, x: f32) Color {
        return Color{
            .r = _clamp(x * self.r),
            .g = _clamp(x * self.g),
            .b = _clamp(x * self.b),
        };
    }

    pub fn add_color(self: *Color, color: Color) void {
        self.r = _clamp(self.r + color.r);
        self.g = _clamp(self.g + color.g);
        self.b = _clamp(self.b + color.b);
    }

    pub fn sum_color(self: *const Color, color: Color) Color {
        return Color{
            .r = _clamp(self.r + color.r),
            .g = _clamp(self.g + color.g),
            .b = _clamp(self.b + color.b),
        };
    }

    pub fn multiply_with_other_color(
        self: *const Color,
        color: *const Color,
    ) Color {
        return Color{
            .r = _clamp(self.r * color.r),
            .g = _clamp(self.g * color.g),
            .b = _clamp(self.b * color.b),
        };
    }

    pub fn _clamp(value: f32) f32 {
        return @max(@min(value, 1), 0);
    }
};

pub const COLOR_BlACK = Color{ .r = 0, .g = 0, .b = 0 };
pub const COLOR_WHITE = Color{ .r = 1, .g = 1, .b = 1 };
pub const COLOR_RED = Color{ .r = 1, .g = 0, .b = 0 };
pub const COLOR_GREEN = Color{ .r = 0, .g = 1, .b = 0 };
pub const COLOR_BLUE = Color{ .r = 0, .g = 0, .b = 1 };
pub const COLOR_GREY = Color{ .r = 0.5, .g = 0.5, .b = 0.5 };

pub const COLOR_EMPTY = Color{ .r = 0.5, .g = 0, .b = 0.5 };
pub const COLOR_DEFAULT = COLOR_GREY;

pub fn cast_jp_color_to_u8(color_value: f32) u8 {
    var calibrated_value = color_value;
    if (calibrated_value > 1) {
        calibrated_value = 1;
    }
    if (calibrated_value < 0) {
        calibrated_value = 0;
    }
    calibrated_value = calibrated_value * 255;
    calibrated_value = @round(calibrated_value);
    const as_int: i32 = @intFromFloat(calibrated_value);
    const as_u8: u8 = @intCast(as_int);
    return as_u8;
}
