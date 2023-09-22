const std = @import("std");
const types = @import("types.zig");
const allocator = std.heap.page_allocator;
const stdout = std.io.getStdOut().writer();

pub const Camera = struct {
    position: types.Vec3i32 = undefined,
    focal_length: i32 = undefined,
    direction: types.Vec3i32 = types.Vec3i32{
        .x = 0,
        .y = 0,
        .z = 1,
    },
};

fn get_ray_direction(
    camera: *const Camera,
    focal_plane_center: types.Vec3i32,
    screen_width: u16,
    screen_height: u16,
    x: u16,
    y: u16,
) types.Vec3i32 {
    const half_x = screen_width / 2;
    const half_y = screen_height / 2;

    const focal_plane_center_to_px_position = types.Vec3i32{
        .x = @as(i32, x) - @as(i32, half_x),
        .y = @as(i32, y) - @as(i32, half_y),
        .z = 0,
    };
    const screen_px_focal_plane_position = focal_plane_center.sum_vector(
        &focal_plane_center_to_px_position,
    );
    const ray_direction = screen_px_focal_plane_position.substract_vector(&camera.position);
    return ray_direction;
}

fn get_focal_plane_center(camera: *const Camera) types.Vec3i32 {
    // camera.pos + camera.direction * focal_length
    const weighted_direction: types.Vec3i32 = camera.direction.product_scalar(
        camera.focal_length,
    );
    return camera.position.sum_vector(&weighted_direction);
}

test "get_focal_plane_center_on_valid_case" {
    const camera = Camera{
        .position = types.Vec3i32{
            .x = 0,
            .y = 0,
            .z = -20,
        },
        .focal_length = 10,
    };
    const center = get_focal_plane_center(&camera);
    try stdout.print("{d}, {d}, {d}", .{ center.x, center.y, center.z });
    try std.testing.expectEqual(center.x, 0);
    try std.testing.expectEqual(center.y, 0);
    try std.testing.expectEqual(center.z, -10);
}

test "get_ray_direction_on_valid_case" {
    const camera = Camera{
        .position = types.Vec3i32{
            .x = 0,
            .y = 0,
            .z = -20,
        },
        .focal_length = 10,
    };
    const focal_center = get_focal_plane_center(&camera);
    var ray_direction = get_ray_direction(&camera, focal_center, 30, 30, 0, 0);
    try std.testing.expectEqual(ray_direction.x, -15);
    try std.testing.expectEqual(ray_direction.y, -15);
    try std.testing.expectEqual(ray_direction.z, 10);
}
