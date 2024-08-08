const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const constants = @import("constants.zig");

const definitions = @import("definitions.zig");
const ShapeEnum = definitions.ShapeEnum;
const Shape = definitions.Shape;
const Camera = definitions.Camera;
const Environment = definitions.Environment;

const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");

const Vec3f32 = maths_vec.Vec3f32;
const TMatrix = maths_tmat.TMatrix;

const data_handles = @import("data_handle.zig");

const utils_geo = @import("utils_geo.zig");

pub const ControllerObject = @This();

const ErrorControllerObject = error{ NameAlreadyTaken, InvalidHandle };

// "entities"
array_camera: std.ArrayList(?CameraEntity),
array_shape: std.ArrayList(?ShapeEntity),
array_env: std.ArrayList(?EnvironmentEntity),

// "components"
array_tmatrix: std.ArrayList(?TMatrix),
array_name: std.ArrayList(?[]const u8),

pub fn init() ControllerObject {
    return .{
        .array_name = std.ArrayList(?[]const u8).init(gpa),
        .array_tmatrix = std.ArrayList(?TMatrix).init(gpa),
        .array_camera = std.ArrayList(?CameraEntity).init(gpa),
        .array_shape = std.ArrayList(?ShapeEntity).init(gpa),
        .array_env = std.ArrayList(?EnvironmentEntity).init(gpa),
    };
}

pub fn deinit(self: *ControllerObject) void {
    self.array_name.deinit();
    self.array_tmatrix.deinit();
    self.array_camera.deinit();
    self.array_shape.deinit();
    self.array_env.deinit();
}

pub const CameraEntity = struct {
    data: Camera,
    handle_name: data_handles.HandleObjectName,
    handle_tmatrix: data_handles.HandleTMatrix,

    pub const CAMERA_DIRECTION = Vec3f32.create_z_neg();
};

pub const ShapeEntity = struct {
    data: Shape,
    handle_name: data_handles.HandleObjectName,
    handle_material: data_handles.HandleMaterial,
    handle_tmatrix: data_handles.HandleTMatrix,
};

pub const EnvironmentEntity = struct {
    data: Environment,
    handle_name: data_handles.HandleObjectName,
};

pub const ObjectPointerEnum = union(data_handles.HandleObjectAllEnum) {
    HandleCamera: *const CameraEntity,
    HandleShape: *const ShapeEntity,
    HandleEnv: *const EnvironmentEntity,
    HandleObjectName: *const []u8,
    HandleTMatrix: *const TMatrix,
};

pub const HitRecord = struct {
    does_hit: u1 = 0, // 0: false, 1: true
    face_side: u1 = 0, // 0: front side, 1: back side.
    p: Vec3f32 = maths_vec.Vec3f32.create_origin(), // hit point position.
    t: f32 = 0, // ray distance.
    n: Vec3f32 = maths_vec.Vec3f32.create_origin(), // normal
    handle_mat: data_handles.HandleMaterial = undefined,
    handle_hittable: data_handles.HandleHRayHittableObjects = undefined,
};

pub fn add_camera(
    self: *ControllerObject,
    name: []const u8,
    camera: Camera,
    tmatrix: TMatrix,
) !data_handles.HandleCamera {
    const handle_name: data_handles.HandleObjectName = try self._add_name(name);
    errdefer self._remove_name(handle_name);

    const handle_tmatrix: data_handles.HandleTMatrix = try self._add_tmatrix(tmatrix);
    errdefer self._remove_tmatrix(handle_tmatrix);

    const handle_camera = data_handles.HandleCamera{
        .idx = self.array_camera.items.len,
    };

    try self.array_camera.append(CameraEntity{
        .handle_name = handle_name,
        .handle_tmatrix = handle_tmatrix,
        .data = camera,
    });
    return handle_camera;
}

pub fn add_shape(
    self: *ControllerObject,
    name: []const u8,
    shape: Shape,
    tmatrix: TMatrix,
    handle_mat: data_handles.HandleMaterial,
) !data_handles.HandleShape {
    const handle_name: data_handles.HandleObjectName = try self._add_name(name);
    errdefer self._remove_name(handle_name);

    const handle_tmatrix: data_handles.HandleTMatrix = try self._add_tmatrix(tmatrix);
    errdefer self._remove_tmatrix(handle_tmatrix);

    const handle_shape = data_handles.HandleShape{ .idx = self.array_shape.items.len };

    try self.array_shape.append(ShapeEntity{
        .handle_name = handle_name,
        .handle_tmatrix = handle_tmatrix,
        .handle_material = handle_mat,
        .data = shape,
    });
    return handle_shape;
}

// TEST ME!
pub fn add_env(
    self: *ControllerObject,
    name: []const u8,
    environment: Environment,
) !data_handles.HandleEnv {
    const handle_name: data_handles.HandleObjectName = try self._add_name(name);
    errdefer self._remove_name(handle_name);
    const handle_env = data_handles.HandleEnv{ .idx = self.array_shape.items.len };

    try self.array_env.append(EnvironmentEntity{
        .handle_name = handle_name,
        .data = environment,
    });
    return handle_env;
}

// TODO: make this generic using comptime?

pub fn get_camera_pointer(
    self: *ControllerObject,
    handle: data_handles.HandleCamera,
) ErrorControllerObject!*CameraEntity {
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
) ErrorControllerObject!*ShapeEntity {
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
) ErrorControllerObject!*EnvironmentEntity {
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

pub fn check_collision_with_shape(
    self: *ControllerObject,
    ray_direction: Vec3f32,
    ray_origin: Vec3f32,
    shape_idx: usize,
) !utils_geo.HitResult {
    const shape = self.array_shape.items[shape_idx].?;
    const tmat = self.array_tmatrix.items[shape.handle_tmatrix.idx].?;
    const pos = tmat.get_position();
    return try switch (shape.data) {
        .ImplicitSphere => utils_geo.check_ray_hit_implicit_sphere(
            ray_direction,
            ray_origin,
            pos,
            shape.data.ImplicitSphere.radius,
        ),
        .ImplicitPlane => utils_geo.check_ray_hit_implicit_plane(
            ray_direction,
            ray_origin,
            pos,
            shape.data.ImplicitPlane.normal,
        ),
    };
}

pub fn check_collision_with_env(
    self: *ControllerObject,
    ray_direction: Vec3f32,
    ray_origin: Vec3f32,
    env_idx: usize,
) !utils_geo.HitResult {
    const env = self.array_env.items[env_idx].?;
    return try switch (env.data) {
        .SkyDome => return utils_geo.check_ray_hit_skydome(
            ray_direction,
            ray_origin,
        ),
    };
}

pub fn get_shape_normal(
    self: *ControllerObject,
    ray_direction: Vec3f32,
    shape_idx: usize,
    hit_point: Vec3f32,
) struct { normal: Vec3f32, face_side: u1 } {
    const shape = self.array_shape.items[shape_idx].?;
    const tmat = self.array_tmatrix.items[shape.handle_tmatrix.idx].?;
    const n = switch (shape.data) {
        .ImplicitSphere => utils_geo.get_normal_on_implicit_sphere(
            tmat.get_position(),
            hit_point,
        ),
        .ImplicitPlane => utils_geo.get_normal_on_implicit_plane(
            tmat,
            shape.data.ImplicitPlane.normal,
        ),
    };
    const face_side: u1 = if (ray_direction.product_dot(n) > 0) 0 else 1;
    return .{ .normal = n, .face_side = face_side };
}

pub fn get_env_normal(
    self: *ControllerObject,
    ray_direction: Vec3f32,
    env_idx: usize,
    hit_point: Vec3f32,
) struct { normal: Vec3f32, face_side: u1 } {
    const shape = self.array_env.items[env_idx].?;
    const n = switch (shape.data) {
        .SkyDome => utils_geo.get_normal_on_skydome(hit_point),
        inline else => unreachable,
    };
    const face_side: u1 = if (ray_direction.product_dot(n) > 0) 0 else 1;
    return .{ .normal = n, .face_side = face_side };
}

pub fn send_ray_on_shapes(
    self: *ControllerObject,
    ray_direction: Vec3f32,
    ray_origin: Vec3f32,
) HitRecord {
    var buffer_t: f32 = 0;
    var buffer_shape_idx: usize = undefined;

    var i: usize = 0;

    while (i < self.array_shape.items.len) : (i += 1) {
        const hit_result: utils_geo.HitResult = try self.check_collision_with_shape(
            ray_direction,
            ray_origin,
            i,
        );
        if (hit_result.hit == 0 or hit_result.t < constants.EPSILON) continue;
        if (buffer_t == 0 or hit_result.t < buffer_t) {
            buffer_t = hit_result.t;
            buffer_shape_idx = i;
        }
    }

    if (buffer_t == 0) return HitRecord{};

    const p = ray_direction.product(buffer_t).sum_vector(ray_origin);
    const normal_info = self.get_shape_normal(ray_direction, buffer_shape_idx, p);
    const handle_mat = self.array_shape.items[buffer_shape_idx].?.handle_material;

    const handle_shape = data_handles.HandleShape{ .idx = buffer_shape_idx };
    const handle_hittable = data_handles.HandleHRayHittableObjects{ .HandleShape = handle_shape };

    return HitRecord{
        .does_hit = 1,
        .face_side = normal_info.face_side,
        .p = p,
        .t = buffer_t,
        .n = normal_info.normal,
        .handle_mat = handle_mat,
        .handle_hittable = handle_hittable,
    };
}

pub fn send_ray_on_env(
    self: *ControllerObject,
    ray_direction: Vec3f32,
    ray_origin: Vec3f32,
) HitRecord {
    var buffer_t: f32 = 0;
    var buffer_env_idx: usize = undefined;

    var i: usize = 0;

    while (i < self.array_env.items.len) : (i += 1) {
        const hit_result: utils_geo.HitResult = try self.check_collision_with_env(
            ray_direction,
            ray_origin,
            i,
        );
        // TODO fix me.
        // if (hit_result.hit == 0 or hit_result.t < constants.EPSILON) continue;term
        if (buffer_t == 0 or hit_result.t < buffer_t) {
            buffer_t = hit_result.t;
            buffer_env_idx = i;
        }
    }

    if (buffer_t == 0) return HitRecord{};

    const p = ray_direction.product(buffer_t).sum_vector(ray_origin);
    const normal_info = self.get_shape_normal(ray_direction, buffer_env_idx, p);
    const handle_mat = switch (self.array_env.items[buffer_env_idx].?.data) {
        .SkyDome => |v| v.handle_material,
    };

    const handle_env = data_handles.HandleEnv{ .idx = buffer_env_idx };
    const handle_hittable = data_handles.HandleHRayHittableObjects{ .HandleEnv = handle_env };

    return HitRecord{
        .does_hit = 1,
        .face_side = normal_info.face_side,
        .p = p,
        .t = buffer_t,
        .n = normal_info.normal,
        .handle_mat = handle_mat,
        .handle_hittable = handle_hittable,
    };
}

pub fn send_ray_on_hittable(
    self: *ControllerObject,
    ray_direction: Vec3f32,
    ray_origin: Vec3f32,
) HitRecord {
    const hit_record_shape = self.send_ray_on_shapes(ray_direction, ray_origin);
    const hit_record_env = self.send_ray_on_env(ray_direction, ray_origin);
    const hit_slice = [_]HitRecord{ hit_record_shape, hit_record_env };

    var buffer_hit_record: HitRecord = undefined;
    var buffer_t: f32 = 0;

    for (hit_slice) |hit_record| {
        if (buffer_t == 0 or (buffer_hit_record.t < buffer_t)) {
            buffer_hit_record = hit_record;
            buffer_t = buffer_hit_record.t;
        }
    }

    if (buffer_t == 0) {
        return HitRecord{};
    } else {
        return buffer_hit_record;
    }
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

fn _add_tmatrix(self: *ControllerObject, tmatrix: TMatrix) !data_handles.HandleTMatrix {
    const idx: usize = self.array_tmatrix.items.len;
    try self.array_tmatrix.append(tmatrix);
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
    const handle_cam_1: data_handles.HandleCamera = try controller.add_camera(
        "camera1",
        Camera{ .Perspective = .{ .focal_length = 10 } },
        TMatrix.create_at_position(Vec3f32.create_x()),
    );
    try std.testing.expectEqual(0, handle_cam_1.idx);

    // second valid camera.
    const handle_cam_2: data_handles.HandleCamera = try controller.add_camera(
        "camera2",
        Camera{ .Perspective = .{ .focal_length = 10 } },
        TMatrix.create_at_position(Vec3f32.create_x()),
    );
    try std.testing.expectEqual(1, handle_cam_2.idx);
    const handle_cam_2_name = controller.array_camera.items[handle_cam_2.idx].?.handle_name;
    try std.testing.expectEqual("camera2", controller.array_name.items[handle_cam_2_name.idx]);

    // name conflict
    try std.testing.expectError(
        ErrorControllerObject.NameAlreadyTaken,
        controller.add_camera(
            "camera2",
            Camera{ .Perspective = .{} },
            TMatrix.create_identity(),
        ),
    );

    const ptr_cam_1 = try controller.get_camera_pointer(handle_cam_1);
    ptr_cam_1.*.data.Perspective.focal_length = 38;
    try std.testing.expectEqual(38, ptr_cam_1.*.data.Perspective.focal_length);

    controller.deinit();
}

test "u_add_get_sphere" {
    var controller = ControllerObject.init();
    const handle_sphere_1: data_handles.HandleShape = try controller.add_shape(
        "sphere_1",
        Shape{ .ImplicitSphere = .{ .radius = 45 } },
        TMatrix.create_at_position(Vec3f32{ .x = 1, .y = 2, .z = 3 }),
        undefined,
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
        "plane_1",
        Shape{ .ImplicitPlane = .{ .normal = Vec3f32.create_y() } },
        TMatrix.create_at_position(Vec3f32{ .x = 1, .y = 2, .z = 3 }),
        undefined,
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
        "sphere_1",
        Shape{ .ImplicitSphere = .{ .radius = 45 } },
        TMatrix.create_at_position(Vec3f32{ .x = 1, .y = 2, .z = 3 }),
        undefined,
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
