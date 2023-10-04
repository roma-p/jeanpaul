const std = @import("std");
const types = @import("types.zig");
const material = @import("material.zig");
const allocator = std.heap.page_allocator;

pub const ShapeSphere = struct {
    radius: u32 = 10,
};

pub const ShapeCamera = struct {
    focal_length: u32 = 10,
    direction: types.Vec3f32 = types.Vec3f32{ .x = 0, .y = 0, .z = 1 },
};

pub fn create_object_type(comptime shape_type: type) type {
    return struct {
        tmatrix: types.TMatrixf32 = types.TMatrixf32{},
        material: *material.Material = &material.DEFAULT_MATERIAL,
        shape: *shape_type = undefined,
    };
}

pub const ObjCamera = create_object_type(ShapeCamera);
pub const ObjSphere = create_object_type(ShapeSphere);

pub fn create_sphere() !*ObjSphere {
    const sphere = try allocator.create(ShapeSphere);
    sphere.* = ShapeSphere{};
    const obj = try allocator.create(ObjSphere);
    obj.* = ObjSphere{
        .shape = sphere,
    };
    return obj;
}

pub fn create_camera() !*ObjCamera {
    const camera = try allocator.create(ShapeCamera);
    camera.* = ShapeCamera{};
    const obj = try allocator.create(ObjCamera);
    obj.* = ObjCamera{
        .shape = camera,
    };
    return obj;
}

pub fn delete_obj(obj: anytype) void {
    allocator.destroy(obj.shape);
    allocator.destroy(obj);
}

test "create_camera" {
    const camera = try create_camera();
    try std.testing.expectEqual(camera.shape.focal_length, 10);
    delete_obj(camera);
}

test "create_sphere" {
    const sphere = try create_sphere();
    try std.testing.expectEqual(sphere.shape.radius, 10);
    delete_obj(sphere);
}
