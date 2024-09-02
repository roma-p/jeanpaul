const std = @import("std");

const maths_vec = @import("maths_vec.zig");
const Vec3f32 = maths_vec.Vec3f32;

pub const Ray = struct {
    o: Vec3f32 = undefined,
    d: Vec3f32 = undefined,

    pub fn create_null() Ray {
        return Ray{
            .o = Vec3f32.create_origin(),
            .d = Vec3f32.create_origin(),
        };
    }

    pub fn log_debug(self: Ray) void {
        std.debug.print("\nRay\n", .{});
        std.debug.print(
            "o -> x:{d}, y:{d}, z:{d}\n",
            .{ self.o.x, self.o.y, self.o.z },
        );
        std.debug.print(
            "d -> x:{d}, y:{d}, z:{d}\n",
            .{ self.d.x, self.d.y, self.d.z },
        );
    }
};
