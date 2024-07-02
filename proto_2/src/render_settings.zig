pub const RenderSettings = @This();

width: u16,
height: u16,
samples: u8,
bounces: u8,

pub fn create_with_default_value() RenderSettings {
    return .{
        .width = 1080,
        .height = 720,
        .samples = 7,
        .bounces = 6,
    };
}
