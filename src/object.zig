const std = @import("std");
const types = @import("types.zig");
const material = @import("material.zig");
const allocator = std.heap.page_allocator;

pub const Object = struct {
    tmatrix: *types.TMatrixf32 = undefined,
    material: *material.Material = &material.MATERIAL_DEFAULT,
    shape: *Shape = undefined,
    object_type: ObjectType,
};

pub const ObjectType = enum { Camera, Light, Mesh, Implicit };

pub const Shape = union(enum) {
    Sphere: *ShapeSphere,
    Camera: *ShapeCamera,
};

pub const ShapeSphere = struct {
    radius: f32 = 10,
};

pub const ShapeCamera = struct {
    focal_length: f32 = 10,
    direction: types.Vec3f32 = types.Vec3f32{ .x = 0, .y = 0, .z = 1 },
};

pub fn create_sphere() !*Object {
    var sphere = try allocator.create(ShapeSphere);
    sphere.* = ShapeSphere{};
    var obj = try allocator.create(Object);
    var shape = try allocator.create(Shape);
    shape.* = Shape{ .Sphere = sphere };
    var tmatrix = try create_t_matrix();
    obj.* = Object{
        .shape = shape,
        .object_type = ObjectType.Implicit,
        .tmatrix = tmatrix,
    };
    return obj;
}

pub fn create_camera() !*Object {
    var camera = try allocator.create(ShapeCamera);
    camera.* = ShapeCamera{};
    var obj = try allocator.create(Object);
    var shape = try allocator.create(Shape);
    shape.* = Shape{ .Camera = camera };
    var tmatrix = try create_t_matrix();
    obj.* = Object{
        .shape = shape,
        .object_type = ObjectType.Camera,
        .tmatrix = tmatrix,
    };
    return obj;
}

pub fn delete_obj(obj: *Object) void {
    switch (obj.shape.*) {
        .Camera => allocator.destroy(obj.shape.Camera),
        .Sphere => allocator.destroy(obj.shape.Sphere),
    }
    allocator.destroy(obj.tmatrix);
    allocator.destroy(obj.shape);
    allocator.destroy(obj);
}

pub fn create_t_matrix() !*types.TMatrixf32 {
    var m = try allocator.create([4][4]f32);
    m.* = [_][4]f32{
        [_]f32{ 1, 0, 0, 0 },
        [_]f32{ 0, 1, 0, 0 },
        [_]f32{ 0, 0, 1, 0 },
        [_]f32{ 0, 0, 0, 1 },
    };
    var tmatrix = try allocator.create(types.TMatrixf32);
    tmatrix.* = types.TMatrixf32{ .m = m.* };
    return tmatrix;
}

test "create_camera" {
    const camera = try create_camera();
    try std.testing.expectEqual(camera.shape.Camera.focal_length, 10);
    delete_obj(camera);
}

test "create_sphere" {
    const sphere = try create_sphere();
    try std.testing.expectEqual(sphere.shape.Sphere.radius, 10);
    delete_obj(sphere);
}
