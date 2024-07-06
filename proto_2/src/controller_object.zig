const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");

const handles = @import("handle.zig");

pub const ControllerObject = @This();

const SceneError = error{ NameAlreadyTaken, InvalidHandle };

array_camera: std.ArrayList(?Camera),
array_shape: std.ArrayList(?Shape),
array_tmatrix: std.ArrayList(?maths_tmat.TMatrix),
array_name: std.ArrayList(?[]const u8),

pub fn init() ControllerObject {
    return .{
        .array_name = std.ArrayList(?[]const u8).init(gpa),
        .array_tmatrix = std.ArrayList(?maths_tmat.TMatrix).init(gpa),
        .array_camera = std.ArrayList(?Camera).init(gpa),
        .array_shape = std.ArrayList(?Shape).init(gpa),
    };
}

pub fn deinit(self: *ControllerObject) void {
    self.array_name.deinit();
    self.array_tmatrix.deinit();
    self.array_camera.deinit();
    self.array_shape.deinit();
}

pub const Camera = struct {
    tag: Tag,
    handle_name: handles.HandleObjectName,
    handle_tmatrix: handles.HandleTMatrix,
    focal_length: f32 = 10,
    field_of_view: f32 = 60,

    pub const CAMERA_DIRECTION = maths_vec.Vec3f32.create_z_neg();

    pub const Tag = enum { CameraPersp };
};

pub const Shape = struct {
    tag: Tag,
    data: Data,
    handle_name: handles.HandleObjectName,
    handle_material: usize, // TODO
    handle_tmatrix: handles.HandleTMatrix,

    const IMPLICIT_PLANE_DIRECTION = maths_vec.Vec3f32.create_y();

    const Tag = enum {
        ImplicitSphere,
        ImplicitPlane,
    };

    const Data = union(Tag) {
        ImplicitSphere: struct {
            radius: f32 = 10,
        },
        ImplicitPlane: struct {
            normal: maths_vec.Vec3f32 = maths_vec.Vec3f32.create_y(),
        },
    };
};

pub fn add_camera(
    self: *ControllerObject,
    name: []const u8,
) !handles.HandleCamera {
    const handle_name: handles.HandleObjectName = try self._add_name(name);
    const handle_tmatrix: handles.HandleTMatrix = try self._add_tmatrix();
    const handle_camera = handles.HandleCamera{
        .idx = self.array_camera.items.len,
    };

    try self.array_camera.append(Camera{
        .handle_name = handle_name,
        .handle_tmatrix = handle_tmatrix,
        .tag = Camera.Tag.CameraPersp,
    });
    return handle_camera;
}

pub fn add_shape(
    self: *ControllerObject,
    name: []const u8,
    tag: Shape.Tag,
) !handles.HandleShape {
    const handle_name: handles.HandleObjectName = try self._add_name(name);
    const handle_tmatrix: handles.HandleTMatrix = try self._add_tmatrix();
    const handle_shape = handles.HandleShape{ .idx = self.array_shape.items.len };

    try self.array_shape.append(Shape{
        .handle_name = handle_name,
        .handle_tmatrix = handle_tmatrix,
        .handle_material = 0, // TODO
        .tag = tag,
        .data = switch (tag) {
            Shape.Tag.ImplicitSphere => Shape.Data{ .ImplicitSphere = .{} },
            Shape.Tag.ImplicitPlane => Shape.Data{ .ImplicitPlane = .{} },
        },
    });
    return handle_shape;
}

pub fn get_camera_pointer(self: *const ControllerObject, handle: handles.HandleCamera) SceneError!*const Camera {
    if (handle.idx > self.array_camera.items.len) {
        return SceneError.InvalidHandle;
    }
    const val = self.array_camera.items[handle.idx] orelse return SceneError.InvalidHandle;
    return &val;
}

pub fn get_shape_pointer(self: *const ControllerObject, handle: handles.HandleShape) SceneError!*const Shape {
    if (handle.idx > self.array_shape.items.len) {
        return SceneError.InvalidHandle;
    }
    const val = self.array_shape.items[handle.idx] orelse return SceneError.InvalidHandle;
    return &val;
}

pub fn get_object_name_pointer(self: *const ControllerObject, handle: handles.HandleObjectName) SceneError!*const []u8 {
    if (handle.idx > self.array_name.items.len) {
        return SceneError.InvalidHandle;
    }
    const val = self.array_name.items[handle.idx] orelse return SceneError.InvalidHandle;
    return &val;
}

pub fn get_tmatrix_pointer(self: *const ControllerObject, handle: handles.HandleTMatrix) SceneError!*const maths_tmat.TMatrix {
    if (handle.idx > self.array_tmatrix.items.len) {
        return SceneError.InvalidHandle;
    }
    const val = self.array_tmatrix.items[handle.idx] orelse return SceneError.InvalidHandle;
    return &val;
}

fn _add_name(self: *ControllerObject, name: []const u8) !handles.HandleObjectName {
    for (self.array_name.items) |existing_name| {
        if (existing_name) |value| {
            if (std.mem.eql(u8, value, name)) {
                return SceneError.NameAlreadyTaken;
            }
        }
    }
    const idx: usize = self.array_name.items.len;
    try self.array_name.append(name);
    return handles.HandleObjectName{ .idx = idx };
}

fn _add_tmatrix(self: *ControllerObject) !handles.HandleTMatrix {
    const idx: usize = self.array_tmatrix.items.len;
    try self.array_tmatrix.append(maths_tmat.TMatrix{});
    return handles.HandleTMatrix{ .idx = idx };
}

test "co_init_deinit" {
    var controller = ControllerObject.init();
    controller.deinit();
}

test "co_add_camera" {
    // first valid camera.
    var controller = ControllerObject.init();
    const cam_1_handle: handles.HandleCamera = try controller.add_camera("camera1");
    try std.testing.expectEqual(0, cam_1_handle.idx);

    // second valid camera.
    const cam_2_handle: handles.HandleCamera = try controller.add_camera("camera2");
    try std.testing.expectEqual(1, cam_2_handle.idx);
    const cam_2_name_handle = controller.array_camera.items[cam_2_handle.idx].?.handle_name;
    try std.testing.expectEqual("camera2", controller.array_name.items[cam_2_name_handle.idx]);

    // name conflict
    try std.testing.expectError(SceneError.NameAlreadyTaken, controller.add_camera("camera2"));

    // get camera
    const handle_cam = handles.HandleCamera{ .idx = 1 };
    const cam_pointer = try controller.get_camera_pointer(handle_cam);
    try std.testing.expectEqual(10, cam_pointer.*.focal_length);

    controller.deinit();
}

test "co_add_sphere" {
    var controller = ControllerObject.init();
    const sphere_1_handle: handles.HandleShape = try controller.add_shape(
        "sphere1",
        Shape.Tag.ImplicitSphere,
    );

    try std.testing.expectEqual(0, sphere_1_handle.idx);
    try std.testing.expectEqual(
        10,
        controller.array_shape.items[sphere_1_handle.idx].?.data.ImplicitSphere.radius,
    );
}

test "co_add_plane" {
    var controller = ControllerObject.init();
    const plane_1_handle: handles.HandleShape = try controller.add_shape(
        "plane",
        Shape.Tag.ImplicitPlane,
    );

    try std.testing.expectEqual(0, plane_1_handle.idx);
    try std.testing.expectEqual(
        1,
        controller.array_shape.items[plane_1_handle.idx].?.data.ImplicitPlane.normal.y,
    );
}
