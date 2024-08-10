const std = @import("std");

// values are betwen 0 and 1.
pub const Color = struct {
    r: f32 = undefined,
    g: f32 = undefined,
    b: f32 = undefined,

    pub fn create_from_value_not_clamped(value: f32) Color {
        return Color{
            .r = value,
            .g = value,
            .b = value,
        };
    }

    pub fn product(self: Color, x: f32) Color {
        return Color{
            .r = x * self.r,
            .g = x * self.g,
            .b = x * self.b,
        };
    }

    pub fn sum_to_color(self: *Color, color: Color) void {
        self.r = self.r + color.r;
        self.g = self.g + color.g;
        self.b = self.b + color.b;
    }

    pub fn sum_color(self: Color, color: Color) Color {
        return Color{
            .r = self.r + color.r,
            .g = self.g + color.g,
            .b = self.b + color.b,
        };
    }

    pub fn sum_with_float(self: Color, x: f32) Color {
        return Color{
            .r = self.r + x,
            .g = self.g + x,
            .b = self.b + x,
        };
    }

    pub fn multiply_color(
        self: Color,
        color: Color,
    ) Color {
        return Color{
            .r = self.r * color.r,
            .g = self.g * color.g,
            .b = self.b * color.b,
        };
    }

    pub fn log_debug(self: Color) void {
        std.debug.print(
            "\nColor -> r:{d}, g:{d}, b:{d}\n",
            .{ self.r, self.g, self.b },
        );
    }

    pub fn clamp(self: Color) Color {
        return Color{
            .r = _clamp(self.r),
            .g = _clamp(self.g),
            .b = _clamp(self.b),
        };
    }

    fn _clamp(value: f32) f32 {
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

    if (std.math.isNan(calibrated_value)) calibrated_value = 0;

    calibrated_value = @round(calibrated_value);
    const as_int: i32 = @intFromFloat(calibrated_value);
    const as_u8: u8 = @intCast(as_int);
    return as_u8;
}

test "multiply" {
    const c = COLOR_GREY.product(0.3);
    try std.testing.expectEqual(0.15, c.r);
    try std.testing.expectEqual(0.15, c.g);
    try std.testing.expectEqual(0.15, c.b);
}

test "sum_to_color" {
    var c1 = Color{ .r = 1, .g = 0.5, .b = 0 };
    const c2 = Color{ .r = 0.1, .g = 0.5, .b = 0.3 };
    c1.sum_to_color(c2);
    try std.testing.expectEqual(1.1, c1.r);
    try std.testing.expectEqual(1, c1.g);
    try std.testing.expectEqual(0.3, c1.b);
}

test "sum_color" {
    const c1 = Color{ .r = 1, .g = 0.5, .b = 0 };
    const c2 = Color{ .r = 0.1, .g = 0.5, .b = 0.3 };
    const c3 = c1.sum_color(c2);
    try std.testing.expectEqual(1.1, c3.r);
    try std.testing.expectEqual(1, c3.g);
    try std.testing.expectEqual(0.3, c3.b);
}

test "multiply_color" {
    const c1 = Color{ .r = 1, .g = 0.5, .b = 0 };
    const c2 = Color{ .r = 0.1, .g = 0.5, .b = 0.3 };
    const c3 = c1.multiply_color(c2);
    try std.testing.expectEqual(0.1, c3.r);
    try std.testing.expectEqual(0.25, c3.g);
    try std.testing.expectEqual(0, c3.b);
}
