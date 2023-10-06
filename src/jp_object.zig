const std = @import("std");
const types = @import("types.zig");
const jp_material = @import("jp_material.zig");
const allocator = std.heap.page_allocator;

pub const JpObject = struct {
    tmatrix: *types.TMatrixf32 = undefined,
    material: *jp_material.JpMaterial = undefined,
    shape: *Shape = undefined,
    object_type: JpObjectType,
};

pub const JpObjectType = enum { Camera, Light, Mesh, Implicit };

pub const Shape = union(enum) {
    Sphere: *ShapeSphere,
    Camera: *ShapeCamera,
};

const ShapeSphere = struct {
    radius: f32 = 10,
};

const ShapeCamera = struct {
    focal_length: f32 = 10,
    field_of_view: f32 = 60,
    direction: types.Vec3f32 = types.Vec3f32{ .x = 0, .y = 0, .z = 1 },
};

pub fn create_sphere() !*JpObject {
    var sphere = try allocator.create(ShapeSphere);
    sphere.* = ShapeSphere{};
    var obj = try allocator.create(JpObject);
    var shape = try allocator.create(Shape);
    shape.* = Shape{ .Sphere = sphere };
    var tmatrix = try create_t_matrix();
    obj.* = JpObject{
        .shape = shape,
        .object_type = JpObjectType.Implicit,
        .tmatrix = tmatrix,
    };
    return obj;
}

pub fn create_camera() !*JpObject {
    var camera = try allocator.create(ShapeCamera);
    camera.* = ShapeCamera{};
    var obj = try allocator.create(JpObject);
    var shape = try allocator.create(Shape);
    shape.* = Shape{ .Camera = camera };
    var tmatrix = try create_t_matrix();
    obj.* = JpObject{
        .shape = shape,
        .object_type = JpObjectType.Camera,
        .tmatrix = tmatrix,
    };
    return obj;
}

pub fn delete_obj(obj: *JpObject) void {
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
