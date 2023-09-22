const std = @import("std");
const types = @import("types.zig");
const allocator = std.heap.page_allocator;

pub const PrimCamera = struct {
    position: types.Vec3u32 = undefined,
    focal_length: u32 = undefined,
};

pub const PrimSphere = struct {
    position: types.Vec3u32 = undefined,
    radius: u32 = undefined,
};

test "create_scene_sphere_at_zero" {

    const camera = PrimCamera{
        .position = types.Vec3u32{
            .x = 0,
            .y = 0,
            .z = 20,
        },
        .focal_length = 10,
    };

}
