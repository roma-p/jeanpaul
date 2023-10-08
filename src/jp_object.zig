const std = @import("std");
const types = @import("types.zig");
const jp_material = @import("jp_material.zig");
const jp_color = @import("jp_color.zig");
const allocator = std.heap.page_allocator;

pub const JpObject = struct {
    tmatrix: *types.TMatrixf32 = undefined,
    material: *jp_material.JpMaterial = undefined,
    shape: *Shape = undefined,
    object_type: JpObjectType,
    object_name: []const u8,
};

pub const JpObjectType = enum { Camera, Light, Mesh, Implicit };

pub fn create_sphere(name: []const u8) !*JpObject {
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
        .object_name = name,
    };
    return obj;
}

pub fn create_camera(name: []const u8) !*JpObject {
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
        .object_name = name,
    };
    return obj;
}

pub fn create_light_omni(name: []const u8) !*JpObject {
    var light = try allocator.create(ShapeLightOmni);
    light.* = ShapeLightOmni{};
    var obj = try allocator.create(JpObject);
    var shape = try allocator.create(Shape);
    shape.* = Shape{ .LightOmni = light };
    var tmatrix = try create_t_matrix();
    obj.* = JpObject{
        .shape = shape,
        .object_type = JpObjectType.Light,
        .tmatrix = tmatrix,
        .object_name = name,
    };
    return obj;
}

pub fn get_normal_at_position(obj: *JpObject, position: types.Vec3f32) types.Vec3f32 {
    var normal: types.Vec3f32 = undefined;
    switch (obj.shape.*) {
        .Sphere => {
            normal = get_normal_point_at_position_sphere(obj, position);
        },
        else => unreachable,
    }
    return normal;
}

fn get_normal_point_at_position_sphere(
    obj: *JpObject,
    position: types.Vec3f32,
) types.Vec3f32 {
    var ret: types.Vec3f32 = position.substract_vector(&obj.tmatrix.get_position());
    ret = ret.normalize();
    return ret;
}

pub fn delete_obj(obj: *JpObject) void {
    switch (obj.shape.*) {
        .Camera => allocator.destroy(obj.shape.Camera),
        .Sphere => allocator.destroy(obj.shape.Sphere),
        .LightOmni => allocator.destroy(obj.shape.LightOmni),
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

pub const Shape = union(enum) {
    Sphere: *ShapeSphere,
    Camera: *ShapeCamera,
    LightOmni: *ShapeLightOmni,
};

const ShapeSphere = struct {
    radius: f32 = 10,
};

const ShapeCamera = struct {
    focal_length: f32 = 10,
    field_of_view: f32 = 60,
    direction: types.Vec3f32 = types.Vec3f32{ .x = 0, .y = 0, .z = 1 },
};

const ShapeLightOmni = struct {
    color: jp_color.JpColor = jp_color.JP_COLOR_GREY,
};
