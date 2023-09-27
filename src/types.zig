pub const Color = struct {
    r: u8 = undefined,
    g: u8 = undefined,
    b: u8 = undefined,
};

pub const Vec2u16 = struct {
    x: u16 = undefined,
    y: u16 = undefined,
};

pub const Vec3f32 = struct {
    x: f32 = undefined,
    y: f32 = undefined,
    z: f32 = undefined,

    pub fn product_scalar(self: *const Vec3f32, x: f32) Vec3f32 {
        return Vec3f32{
            .x = x * self.x,
            .y = x * self.y,
            .z = x * self.z,
        };
    }

    pub fn substract_vector(self: *const Vec3f32, vec: *const Vec3f32) Vec3f32 {
        return Vec3f32{
            .x = self.x - vec.x,
            .y = self.y - vec.y,
            .z = self.z - vec.z,
        };
    }

    pub fn sum_vector(self: *const Vec3f32, vec: *const Vec3f32) Vec3f32 {
        return Vec3f32{
            .x = self.x + vec.x,
            .y = self.y + vec.y,
            .z = self.z + vec.z,
        };
    }

    pub fn product_dot(self: *const Vec3f32, vec: *const Vec3f32) f32 {
        return self.x * vec.x + self.y * vec.y + self.z * vec.z;
    }
};

pub const BoudingRectangleu16 = struct {
    x_min: u16 = undefined,
    x_max: u16 = undefined,
    y_min: u16 = undefined,
    y_max: u16 = undefined,
};

pub fn cast_u16_to_f32(input: u16) f32 {
    // didn't find how to do this directly without casting as int first...
    // used mainly to go from screen space (2d u16 array) to 3d space (3d f32 array)
    const tmp: i32 = input;
    const ret: f32 = @floatFromInt(tmp);
    return ret;
}
