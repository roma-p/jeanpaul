const std = @import("std");
const types = @import("types.zig");
const material = @import("material.zig");
const allocator = std.heap.page_allocator;

pub const Object = struct {
    tmatrix: types.TMatrixf32 = types.TMatrixf32{},
    material: *material.Material = &material.DEFAULT_MATERIAL,
    shape: *Shape = undefined,
};

pub const Shape = union(enum) {
    Sphere: *ShapeSphere,
    Camera: *ShapeCamera,
};

pub const ShapeSphere = struct {
    radius: u32 = 10,
};

pub const ShapeCamera = struct {
    focal_length: u32 = 10,
    direction: types.Vec3f32 = types.Vec3f32{ .x = 0, .y = 0, .z = 1 },
};

pub fn create_sphere() !*Object {
    var sphere = try allocator.create(ShapeSphere);
    sphere.* = ShapeSphere{};
    var obj = try allocator.create(Object);
    var shape = try allocator.create(Shape);
    shape.* = Shape{ .Sphere = sphere };
    obj.* = Object{ .shape = shape };
    return obj;
}

pub fn create_camera() !*Object {
    var camera = try allocator.create(ShapeCamera);
    camera.* = ShapeCamera{};
    var obj = try allocator.create(Object);
    var shape = try allocator.create(Shape);
    shape.* = Shape{ .Camera = camera };
    obj.* = Object{ .shape = shape };
    return obj;
}

pub fn delete_obj(obj: *Object) void {
    switch (obj.shape.*) {
        .Camera => allocator.destroy(obj.shape.Camera),
        .Sphere => allocator.destroy(obj.shape.Sphere),
    }
    allocator.destroy(obj.shape);
    allocator.destroy(obj);
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
