const std = @import("std");
const types = @import("types.zig");
const jp_material = @import("jp_material.zig");
const jp_color = @import("jp_color.zig");
const allocator = std.heap.page_allocator;

// ==== Constants ============================================================

pub const ShapeTypeId = enum {
    ImplicitSphere,
    CameraPersp,
    LightOmni,
};

pub const ShapeTypeIdArray = [_]ShapeTypeId{
    .ImplicitSphere,
    .CameraPersp,
    .LightOmni,
};

pub const JpObjectCategory = enum {
    Camera,
    Light,
    Mesh,
    Implicit,
};

pub const Shape = union(ShapeTypeId) {
    ImplicitSphere: *ShapeSphere,
    CameraPersp: *ShapeCamera,
    LightOmni: *ShapeLightOmni,
};

// ==== JpObject ==============================================================

pub const JpObject = struct {
    tmatrix: *types.TMatrixf32 = undefined,
    material: *jp_material.JpMaterial = undefined,
    shape: *Shape = undefined,
    name: []const u8,

    const Self = @This();

    pub fn new(name: []const u8, shape_type_id: ShapeTypeId) !*Self {
        var tmatrix = try types.TMatrixf32.new();
        errdefer tmatrix.delete();

        var obj = try allocator.create(JpObject);
        errdefer obj.delete();

        obj.* = JpObject{
            .shape = undefined,
            .tmatrix = tmatrix,
            .name = name,
        };
        try shape_builder(shape_type_id, obj);
        return obj;
    }

    pub fn delete(self: *Self) void {
        shape_deleter(self);
        self.tmatrix.delete();
        allocator.destroy(self.tmatrix);
        allocator.destroy(self);
    }

    pub fn get_category(self: *Self) JpObjectCategory {
        switch (self.shape.*) {
            inline else => |t| return t.object_category,
        }
    }
};

// ==== Shape Definition =====================================================

const ShapeSphere = struct {
    comptime object_category: JpObjectCategory = JpObjectCategory.Implicit,
    radius: f32 = 10,
};

const ShapeCamera = struct {
    //TODO: use interface to add "get_category" and not duplicate infos...
    comptime object_category: JpObjectCategory = JpObjectCategory.Camera,
    comptime DIRECTION: types.Vec3f32 = types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = 1,
    },
    focal_length: f32 = 10,
    field_of_view: f32 = 60,
    //FIXME: delme -> use DIRECTION instead!
    //FIXME: default direction is generally: 0, 0, -1
    direction: types.Vec3f32 = types.Vec3f32{ .x = 0, .y = 0, .z = 1 },
};

const ShapeLightOmni = struct {
    comptime object_category: JpObjectCategory = JpObjectCategory.Light,
    color: jp_color.JpColor = jp_color.JP_COLOR_GREY,
    intensity: f32 = 0.7,
};

// ==== HELPERS ==============================================================

pub fn get_normal_at_position(obj: *JpObject, position: types.Vec3f32) types.Vec3f32 {
    var normal: types.Vec3f32 = undefined;
    switch (obj.shape.*) {
        .ImplicitSphere => {
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

fn shape_builder(type_id: ShapeTypeId, jp_object: *JpObject) !void {
    var shape = try allocator.create(Shape);
    switch (type_id) {
        // IMPLICIT ----------------------------------------------------------
        .ImplicitSphere => {
            var _actual_shape = try allocator.create(ShapeSphere);
            _actual_shape.* = ShapeSphere{};
            shape.* = Shape{ .ImplicitSphere = _actual_shape };
        },
        // CAMERA ------------------------------------------------------------
        .CameraPersp => {
            var _actual_shape = try allocator.create(ShapeCamera);
            _actual_shape.* = ShapeCamera{};
            shape.* = Shape{ .CameraPersp = _actual_shape };
        },
        // LIGHT -------------------------------------------------------------
        .LightOmni => {
            var _actual_shape = try allocator.create(ShapeLightOmni);
            _actual_shape.* = ShapeLightOmni{};
            shape.* = Shape{ .LightOmni = _actual_shape };
        },
    }
    jp_object.shape = shape;
}

fn shape_deleter(jp_object: *JpObject) void {
    switch (jp_object.shape.*) {
        .CameraPersp => allocator.destroy(jp_object.shape.CameraPersp),
        .ImplicitSphere => allocator.destroy(jp_object.shape.ImplicitSphere),
        .LightOmni => allocator.destroy(jp_object.shape.LightOmni),
    }
    allocator.destroy(jp_object.shape);
}
