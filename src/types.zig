pub const Color = struct {
    r: u8 = undefined,
    g: u8 = undefined,
    b: u8 = undefined,
};

pub const Vec2u16 = struct {
    x: u16 = undefined,
    y: u16 = undefined,
};

pub const Vec3i32 = struct {
    x: i32 = undefined,
    y: i32 = undefined,
    z: i32 = undefined,

    pub fn product_scalar(self: *const Vec3i32, x: i32) Vec3i32 {
        return Vec3i32{
            .x = x * self.x,
            .y = x * self.y,
            .z = x * self.z,
        };
    }

    pub fn substract_vector(self: *const Vec3i32, vec: *const Vec3i32) Vec3i32 {
        return Vec3i32{
            .x = self.x - vec.x,
            .y = self.y - vec.y,
            .z = self.z - vec.z,
        };
    }

    pub fn sum_vector(self: *const Vec3i32, vec: *const Vec3i32) Vec3i32 {
        return Vec3i32{
            .x = self.x + vec.x,
            .y = self.y + vec.y,
            .z = self.z + vec.z,
        };
    }
};

pub const BoudingRectangleu32 = struct {
    x_min: u16 = undefined,
    x_max: u16 = undefined,
    y_min: u16 = undefined,
    y_max: u16 = undefined,
};
