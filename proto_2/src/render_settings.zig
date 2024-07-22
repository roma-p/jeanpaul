pub const RenderSettings = @This();

width: u16,
height: u16,
samples: u8,
bounces: u8,
render_type: RenderType,
tile_size: u16,

pub fn create_with_default_value() RenderSettings {
    return .{
        .width = 1080,
        .height = 720,
        .samples = 2,
        .bounces = 6,
        .render_type = RenderType.Tile,
        .tile_size = 64,
    };
}

pub const RenderType = enum {
    SingleThread,
    Scanline,
    Tile,
};
