const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const maths = @import("maths.zig");

pub const ControllerObject = @This();

array_object_camera: std.ArrayList(Camera),
array_object_to_tmatrix: std.ArrayList([4][4]f32),
array_object_to_name: std.ArrayList([]const u8),

pub fn init() ControllerObject {
    return .{
        .array_object_to_name = std.ArrayList([]const u8).init(gpa),
        .array_object_to_tmatrix = std.ArrayList([4][4]f32).init(gpa),
        .array_object_camera = std.ArrayList(Camera).init(gpa),
    };
}

pub fn deinit(self: *ControllerObject) void {
    self.array_object_to_name.deinit();
    self.array_object_camera.deinit();
    self.array_object_to_tmatrix.deinit();
}

pub const Camera = struct {
    tag: Tag,
    handle_name: usize,
    handle_tmatrix: usize,
    focal_length: f32 = 10,
    field_of_view: f32 = 60,

    const CAMERA_DIRECTION = maths.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -1,
    };

    pub const Tag = enum { CameraPersp };
};

pub fn add_camera(self: *ControllerObject, name: []const u8) !usize {

    // Check if name not already taken...

    const handle_name: usize = self.array_object_to_name.items.len;
    const handle_tmatrix: usize = self.array_object_to_tmatrix.items.len;
    const handle_camera: usize = self.array_object_camera.items.len;

    try self.array_object_to_name.append(name);
    try self.array_object_to_tmatrix.append([4][4]f32{
        [4]f32{ 1, 0, 0, 0 },
        [4]f32{ 0, 1, 0, 0 },
        [4]f32{ 0, 0, 1, 0 },
        [4]f32{ 0, 0, 0, 1 },
    });
    try self.array_object_camera.append(Camera{
        .handle_name = handle_name,
        .handle_tmatrix = handle_tmatrix,
        .tag = Camera.Tag.CameraPersp,
    });
    return handle_camera;
}

test "co_init_deinit" {
    var controller = ControllerObject.init();
    controller.deinit();
}

test "co_add_camera" {
    var controller = ControllerObject.init();
    const cam_1_handle: usize = try controller.add_camera("camera1");
    try std.testing.expectEqual(0, cam_1_handle);
    controller.deinit();
}
