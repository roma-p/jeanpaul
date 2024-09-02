pub const RenderSettings = @This();

width: u16 = 1920,
height: u16 = 1080,
samples: u8 = 5,
samples_antialiasing: u8 = 5,
bounces: u8 = 16,
render_type: RenderType = RenderType.Tile,
tile_size: u16 = 64,
color_space: ColorSpace = ColorSpace.DefaultGamma2,

// advanced / dev render settings.
collision_acceleration: CollisionAccelerationMethod = CollisionAccelerationMethod.BvhEqualSize,

pub const RenderType = enum {
    Pixel,
    Scanline,
    Tile,
    SingleThread,
};

pub const ColorSpace = enum {
    DefaultLinear, // lut rgb value TODO, but transfer function is linear.
    DefaultGamma2, // lut rgb value TODO, but transfer function is gamma2.
};

pub const CollisionAccelerationMethod = enum {
    NoAccelerationMethod, // Test collision against every shapes.
    BvhEqualSize, // Bouding box hierarchy, each box holds same number of shapes.
    BvhSAH, // Bouding box hierarchy: Surface Area Heuristics.
};
