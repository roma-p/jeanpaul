const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");

const Vec3f32 = maths_vec.Vec3f32;
const TMatrix = maths_tmat.TMatrix;

const data_handles = @import("data_handle.zig");

pub const ControllerObject = @This();

const ErrorControllerObject = error{ NameAlreadyTaken, InvalidHandle };

// Assuming one default material was created.
const HANDLE_DEFAULT_MATERIAL = data_handles.HandleMaterial{ .idx = 0 };

// "entities"
array_camera: std.ArrayList(?Camera),
array_shape: std.ArrayList(?Shape),
array_env: std.ArrayList(?Environment),

// "components"
array_tmatrix: std.ArrayList(?TMatrix),
array_name: std.ArrayList(?[]const u8),

pub fn init() ControllerObject {
    return .{
        .array_name = std.ArrayList(?[]const u8).init(gpa),
        .array_tmatrix = std.ArrayList(?TMatrix).init(gpa),
        .array_camera = std.ArrayList(?Camera).init(gpa),
        .array_shape = std.ArrayList(?Shape).init(gpa),
        .array_env = std.ArrayList(?Environment).init(gpa),
    };
}

pub fn deinit(self: *ControllerObject) void {
    self.array_name.deinit();
    self.array_tmatrix.deinit();
    self.array_camera.deinit();
    self.array_shape.deinit();
    self.array_env.deinit();
}

pub const Camera = struct {
    tag: Tag,
    handle_name: data_handles.HandleObjectName,
    handle_tmatrix: data_handles.HandleTMatrix,
    focal_length: f32 = 10,
    field_of_view: f32 = 60,

    pub const CAMERA_DIRECTION = Vec3f32.create_z_neg();

    pub const Tag = enum { CameraPersp };
};

pub const Shape = struct {
    tag: Tag,
    data: Data,
    handle_name: data_handles.HandleObjectName,
    handle_material: data_handles.HandleMaterial,
    handle_tmatrix: data_handles.HandleTMatrix,

    const IMPLICIT_PLANE_DIRECTION = Vec3f32.create_y();

    pub const Tag = enum {
        ImplicitSphere,
        ImplicitPlane,
    };

    // TODO: PUT THIS IN "MODEL DEFINITION"...
    const Data = union(Tag) {
        ImplicitSphere: struct {
            radius: f32 = 10,
        },
        ImplicitPlane: struct {
            normal: Vec3f32 = Vec3f32.create_y(),
        },
    };
};

pub const Environment = struct {
    tag: Tag,
    data: Data,
    handle_name: data_handles.HandleObjectName,

    pub const Tag = enum { SkyDome };

    const Data = union(Tag) {
        SkyDome: struct {
            handle_material: data_handles.HandleMaterial,
        },
    };
};

pub const ObjectPointerEnum = union(data_handles.HandleObjectAllEnum) {
    HandleCamera: *const Camera,
    HandleShape: *const Shape,
    HandleEnv: *const Environment,
    HandleObjectName: *const []u8,
    HandleTMatrix: *const TMatrix,
};

pub fn add_camera(
    self: *ControllerObject,
    name: []const u8,
) !data_handles.HandleCamera {
    const handle_name: data_handles.HandleObjectName = try self._add_name(name);
    errdefer self._remove_name(handle_name);

    const handle_tmatrix: data_handles.HandleTMatrix = try self._add_tmatrix();
    errdefer self._remove_tmatrix(handle_tmatrix);

    const handle_camera = data_handles.HandleCamera{
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
) !data_handles.HandleShape {
    const handle_name: data_handles.HandleObjectName = try self._add_name(name);
    errdefer self._remove_name(handle_name);

    const handle_tmatrix: data_handles.HandleTMatrix = try self._add_tmatrix();
    errdefer self._remove_tmatrix(handle_tmatrix);

    const handle_shape = data_handles.HandleShape{ .idx = self.array_shape.items.len };

    try self.array_shape.append(Shape{
        .handle_name = handle_name,
        .handle_tmatrix = handle_tmatrix,
        .handle_material = HANDLE_DEFAULT_MATERIAL,
        .tag = tag,
        .data = switch (tag) {
            Shape.Tag.ImplicitSphere => Shape.Data{ .ImplicitSphere = .{} },
            Shape.Tag.ImplicitPlane => Shape.Data{ .ImplicitPlane = .{} },
        },
    });
    return handle_shape;
}

// TEST ME!
pub fn add_env(
    self: *ControllerObject,
    name: []const u8,
    tag: Environment.Tag,
) !data_handles.HandleEnv {
    const handle_name: data_handles.HandleObjectName = try self._add_name(name);
    errdefer self._remove_name(handle_name);
    const handle_env = data_handles.HandleEnv{ .idx = self.array_shape.items.len };

    try self.array_env.append(Environment{
        .handle_name = handle_name,
        .tag = tag,
        .data = switch (tag) {
            Environment.Tag.SkyDome => Environment.Data{
                .SkyDome = .{ .handle_material = HANDLE_DEFAULT_MATERIAL },
            }, // TODO
        },
    });
    return handle_env;
}

// TODO: make this generic using comptime?

pub fn get_camera_pointer(
    self: *ControllerObject,
    handle: data_handles.HandleCamera,
) ErrorControllerObject!*Camera {
    if (handle.idx > self.array_camera.items.len) {
        return ErrorControllerObject.InvalidHandle;
    }
    if (self.array_camera.items[handle.idx]) |*v| {
        return v;
    } else {
        return ErrorControllerObject.InvalidHandle;
    }
}

pub fn get_shape_pointer(
    self: *ControllerObject,
    handle: data_handles.HandleShape,
) ErrorControllerObject!*Shape {
    if (handle.idx > self.array_shape.items.len) {
        return ErrorControllerObject.InvalidHandle;
    }
    if (self.array_shape.items[handle.idx]) |*v| {
        return v;
    } else {
        return ErrorControllerObject.InvalidHandle;
    }
}

pub fn get_env_pointer(
    self: *ControllerObject,
    handle: data_handles.HandleEnv,
) ErrorControllerObject!*Environment {
    if (handle.idx > self.array_env.items.len) {
        return ErrorControllerObject.InvalidHandle;
    }
    if (self.array_env.items[handle.idx]) |*v| {
        return v;
    } else {
        return ErrorControllerObject.InvalidHandle;
    }
}

pub fn get_object_name_pointer(
    self: *ControllerObject,
    handle: data_handles.HandleObjectName,
) ErrorControllerObject!*const []u8 {
    if (handle.idx > self.array_name.items.len) {
        return ErrorControllerObject.InvalidHandle;
    }
    if (self.array_name.items[handle.idx]) |*v| {
        return v;
    } else {
        return ErrorControllerObject.InvalidHandle;
    }
}

pub fn get_tmatrix_pointer(
    self: *ControllerObject,
    handle: data_handles.HandleTMatrix,
) ErrorControllerObject!*TMatrix {
    if (handle.idx > self.array_tmatrix.items.len) {
        return ErrorControllerObject.InvalidHandle;
    }
    if (self.array_tmatrix.items[handle.idx]) |*v| {
        return v;
    } else {
        return ErrorControllerObject.InvalidHandle;
    }
}

pub fn set_position_from_tmatrix_handle(
    self: *ControllerObject,
    handle: data_handles.HandleTMatrix,
    pos: Vec3f32,
) ErrorControllerObject!void {
    const ptr = try self.get_tmatrix_pointer(handle);
    ptr.set_position(pos);
}

fn _add_name(self: *ControllerObject, name: []const u8) !data_handles.HandleObjectName {
    for (self.array_name.items) |existing_name| {
        if (existing_name) |value| {
            if (std.mem.eql(u8, value, name)) {
                return ErrorControllerObject.NameAlreadyTaken;
            }
        }
    }
    const idx: usize = self.array_name.items.len;
    try self.array_name.append(name);
    return data_handles.HandleObjectName{ .idx = idx };
}

fn _remove_name(self: *ControllerObject, handle: data_handles.HandleObjectName) void {
    if (handle.idx > self.array_name.items.len) return;
    if (self.array_name.items[handle.idx] != null) {
        self.array_name.items[handle.idx] = null;
    }
}

fn _add_tmatrix(self: *ControllerObject) !data_handles.HandleTMatrix {
    const idx: usize = self.array_tmatrix.items.len;
    try self.array_tmatrix.append(TMatrix.create_identity());
    return data_handles.HandleTMatrix{ .idx = idx };
}

fn _remove_tmatrix(self: *ControllerObject, handle: data_handles.HandleTMatrix) void {
    if (handle.idx > self.array_tmatrix.items.len) return;
    if (self.array_tmatrix.items[handle.idx] != null) {
        self.array_name.items[handle.idx] = null;
    }
}

test "i_init_deinit" {
    var controller = ControllerObject.init();
    controller.deinit();
}

test "u_add_get_camera" {
    // first valid camera.
    var controller = ControllerObject.init();
    const handle_cam_1: data_handles.HandleCamera = try controller.add_camera("camera1");
    try std.testing.expectEqual(0, handle_cam_1.idx);

    // second valid camera.
    const handle_cam_2: data_handles.HandleCamera = try controller.add_camera("camera2");
    try std.testing.expectEqual(1, handle_cam_2.idx);
    const handle_cam_2_name = controller.array_camera.items[handle_cam_2.idx].?.handle_name;
    try std.testing.expectEqual("camera2", controller.array_name.items[handle_cam_2_name.idx]);

    // name conflict
    try std.testing.expectError(ErrorControllerObject.NameAlreadyTaken, controller.add_camera("camera2"));

    const ptr_cam_1 = try controller.get_camera_pointer(handle_cam_1);
    ptr_cam_1.*.focal_length = 38;
    try std.testing.expectEqual(38, ptr_cam_1.*.focal_length);

    controller.deinit();
}

test "u_add_get_sphere" {
    var controller = ControllerObject.init();
    const handle_sphere_1: data_handles.HandleShape = try controller.add_shape(
        "sphere1",
        Shape.Tag.ImplicitSphere,
    );
    const ptr_sphere_1 = try controller.get_shape_pointer(handle_sphere_1);
    ptr_sphere_1.data.ImplicitSphere.radius = 16;

    try std.testing.expectEqual(0, handle_sphere_1.idx);

    try std.testing.expectEqual(
        16,
        controller.array_shape.items[handle_sphere_1.idx].?.data.ImplicitSphere.radius,
    );
}

test "u_add_get_plane" {
    var controller = ControllerObject.init();
    const handle_plane_1: data_handles.HandleShape = try controller.add_shape(
        "plane",
        Shape.Tag.ImplicitPlane,
    );
    const ptr_plane_1 = try controller.get_shape_pointer(handle_plane_1);
    ptr_plane_1.data.ImplicitPlane.normal.y = 2;

    try std.testing.expectEqual(0, handle_plane_1.idx);
    try std.testing.expectEqual(
        2,
        controller.array_shape.items[handle_plane_1.idx].?.data.ImplicitPlane.normal.y,
    );
}

test "u_set_position" {
    var controller = ControllerObject.init();
    defer controller.deinit();
    const hdl_sphere1: data_handles.HandleShape = try controller.add_shape(
        "sphere1",
        Shape.Tag.ImplicitSphere,
    );
    const ptr_sphere1 = try controller.get_shape_pointer(hdl_sphere1);
    const ptr_tmatrix = try controller.get_tmatrix_pointer(ptr_sphere1.handle_tmatrix);

    try controller.set_position_from_tmatrix_handle(
        ptr_sphere1.*.handle_tmatrix,
        Vec3f32{ .x = -5, .y = -5, .z = 0 },
    );
    const position = ptr_tmatrix.get_position();
    try std.testing.expectEqual(-5, position.x);
    try std.testing.expectEqual(-5, position.y);
    try std.testing.expectEqual(0, position.z);
}
