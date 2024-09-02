const std = @import("std");
const gpa = std.heap.page_allocator;

const constants = @import("constants.zig");

const maths_vec = @import("maths_vec.zig");
const maths_ray = @import("maths_ray.zig");

const utils_geo = @import("utils_geo.zig");

const data_render_settings = @import("data_render_settings.zig");
const data_handles = @import("data_handle.zig");

const Vec3f32 = maths_vec.Vec3f32;
const Ray = maths_ray.Ray;
const CollisionAccelerationMethod = data_render_settings.CollisionAccelerationMethod;

const RendererRayCollision = @This();

const ControllereObject = @import("controller_object.zig");
const ControllereBvh = @import("controller_bvh.zig");

pub const CollisionAccelerationEngine = enum { None, Bvh };

controller_object: *ControllereObject,
controller_bvh: ControllereBvh,
collision_acceleration_method: CollisionAccelerationMethod,
collision_acceleration_engine: CollisionAccelerationEngine,

pub fn init(
    controller_object: *ControllereObject,
    collision_acceleration_method: CollisionAccelerationMethod,
) !RendererRayCollision {
    const collision_acceleration_engine = switch (collision_acceleration_method) {
        .NoAccelerationMethod => CollisionAccelerationEngine.None,
        .BvhSAH => CollisionAccelerationEngine.Bvh,
        .BvhEqualSize => CollisionAccelerationEngine.Bvh,
    };

    return .{
        .controller_object = controller_object,
        .controller_bvh = switch (collision_acceleration_engine) {
            .None => undefined,
            .Bvh => try ControllereBvh.init(collision_acceleration_method, controller_object),
        },
        .collision_acceleration_method = collision_acceleration_method,
        .collision_acceleration_engine = collision_acceleration_engine,
    };
}

pub fn deinit(self: *RendererRayCollision) void {
    self.controller_bvh.deinit();
}

pub const HitRecord = struct {
    does_hit: u1 = 0, // 0: false, 1: true
    face_side: u1 = 0, // 0: front side, 1: back side.
    ray_direction: Vec3f32 = maths_vec.Vec3f32.create_origin(),
    p: Vec3f32 = maths_vec.Vec3f32.create_origin(), // hit point position.
    t: f32 = 0, // ray distance.
    n: Vec3f32 = maths_vec.Vec3f32.create_origin(), // normal
    handle_mat: data_handles.HandleMaterial = undefined,
    handle_hittable: data_handles.HandleHRayHittableObjects = undefined,
};

pub fn init_collision_accelerator(self: *RendererRayCollision) !void {
    switch (self.collision_acceleration_engine) {
        .None => return,
        .Bvh => try self.controller_bvh.build_bvh(),
    }
}

pub fn send_ray_on_hittable(self: *RendererRayCollision, ray: Ray) HitRecord {
    const hit_record_shape = self.send_ray_on_shapes(ray);
    const hit_record_env = self.send_ray_on_env(ray);
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

fn send_ray_on_env(self: *RendererRayCollision, ray: Ray) HitRecord {
    var buffer_t: f32 = 0;
    var buffer_env_idx: usize = undefined;

    var i: usize = 0;

    while (i < self.controller_object.array_env.items.len) : (i += 1) {
        const hit_result: utils_geo.HitResult = try self.check_collision_with_env(ray, i);
        if (hit_result.hit == 0 or hit_result.t < constants.EPSILON) continue;
        if (buffer_t == 0 or hit_result.t < buffer_t) {
            buffer_t = hit_result.t;
            buffer_env_idx = i;
        }
    }

    if (buffer_t == 0) return HitRecord{};

    const p = ray.d.product(buffer_t).sum_vector(ray.o);
    const normal_info = self.get_shape_normal(ray.d, buffer_env_idx, p);
    const handle_mat = switch (self.controller_object.array_env.items[buffer_env_idx].?.data) {
        .SkyDome => |v| v.handle_material,
    };

    const handle_env = data_handles.HandleEnv{ .idx = buffer_env_idx };
    const handle_hittable = data_handles.HandleHRayHittableObjects{ .HandleEnv = handle_env };

    return HitRecord{
        .does_hit = 1,
        .face_side = normal_info.face_side,
        .ray_direction = ray.d,
        .p = p,
        .t = buffer_t,
        .n = normal_info.normal,
        .handle_mat = handle_mat,
        .handle_hittable = handle_hittable,
    };
}

pub fn send_ray_on_shapes(self: *RendererRayCollision, ray: Ray) HitRecord {
    var buffer_t: f32 = 0;
    var buffer_shape_idx: usize = undefined;

    var i: usize = 0;
    var j: usize = 0;

    var i_end: usize = 0;

    switch (self.collision_acceleration_engine) {
        .Bvh => {
            i_end = self.controller_bvh.traverse_bvh_tree(ray);
        },
        inline else => {
            i_end = self.controller_object.array_shape.items.len;
        },
    }

    while (i < i_end) : (i += 1) {
        j = switch (self.collision_acceleration_engine) {
            .None => i,
            .Bvh => self.controller_bvh.bvh_out_array[i],
        };

        const hit_result: utils_geo.HitResult = try self.check_collision_with_shape(ray, j);
        if (hit_result.hit == 0 or hit_result.t < constants.EPSILON) continue;
        if (buffer_t == 0 or hit_result.t < buffer_t) {
            buffer_t = hit_result.t;
            buffer_shape_idx = j;
        }
    }

    if (buffer_t == 0) return HitRecord{};

    const p = ray.d.product(buffer_t).sum_vector(ray.o);
    const normal_info = self.get_shape_normal(ray.d, buffer_shape_idx, p);
    const handle_mat = self.controller_object.array_shape.items[buffer_shape_idx].?.handle_material;

    const handle_shape = data_handles.HandleShape{ .idx = buffer_shape_idx };
    const handle_hittable = data_handles.HandleHRayHittableObjects{ .HandleShape = handle_shape };

    return HitRecord{
        .does_hit = 1,
        .face_side = normal_info.face_side,
        .ray_direction = ray.d,
        .p = p,
        .t = buffer_t,
        .n = normal_info.normal,
        .handle_mat = handle_mat,
        .handle_hittable = handle_hittable,
    };
}

fn check_collision_with_shape(
    self: *RendererRayCollision,
    ray: Ray,
    shape_idx: usize,
) !utils_geo.HitResult {
    const shape = self.controller_object.array_shape.items[shape_idx].?;
    const tmat = self.controller_object.array_tmatrix.items[shape.handle_tmatrix.idx].?;
    const pos = tmat.get_position();
    return try switch (shape.data) {
        .ImplicitSphere => utils_geo.check_ray_hit_implicit_sphere(
            ray,
            pos,
            shape.data.ImplicitSphere.radius,
        ),
        .ImplicitPlane => utils_geo.check_ray_hit_implicit_plane(
            ray,
            pos,
            shape.data.ImplicitPlane.normal,
        ),
    };
}

pub fn check_collision_with_env(
    self: *RendererRayCollision,
    ray: Ray,
    env_idx: usize,
) !utils_geo.HitResult {
    const env = self.controller_object.array_env.items[env_idx].?;
    return try switch (env.data) {
        .SkyDome => return utils_geo.check_ray_hit_skydome(ray),
    };
}

pub fn get_shape_normal(
    self: *RendererRayCollision,
    ray_direction: Vec3f32,
    shape_idx: usize,
    hit_point: Vec3f32,
) struct { normal: Vec3f32, face_side: u1 } {
    const shape = self.controller_object.array_shape.items[shape_idx].?;
    const tmat = self.controller_object.array_tmatrix.items[shape.handle_tmatrix.idx].?;
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
    self: *RendererRayCollision,
    ray_direction: Vec3f32,
    env_idx: usize,
    hit_point: Vec3f32,
) struct { normal: Vec3f32, face_side: u1 } {
    const shape = self.controller_object.array_env.items[env_idx].?;
    const n = switch (shape.data) {
        .SkyDome => utils_geo.get_normal_on_skydome(hit_point),
        inline else => unreachable,
    };
    const face_side: u1 = if (ray_direction.product_dot(n) > 0) 0 else 1;
    return .{ .normal = n, .face_side = face_side };
}
