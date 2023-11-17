const std = @import("std");
const types = @import("types.zig");
const jp_material = @import("jp_material.zig");
const jp_color = @import("jp_color.zig");
const allocator = std.heap.page_allocator;

// ==== Constants ============================================================

pub const ShapeTypeId = enum {
    ImplicitSphere,
    ImplicitPlane,
    CameraPersp,
    LightOmni,
};

pub const ShapeTypeIdArray = [_]ShapeTypeId{
    .ImplicitSphere,
    .ImplicitPlane,
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
    ImplicitPlane: *ShapePlane,
    CameraPersp: *ShapeCamera,
    LightOmni: *ShapeLightOmni,
};

pub const LightDecayRate = enum {
    NoDecay,
    Quadratic,
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

const ShapePlane = struct {
    comptime object_category: JpObjectCategory = JpObjectCategory.Implicit,
    DIRECTION: types.Vec3f32 = types.Vec3f32{
        .x = 0,
        .y = 1,
        .z = 0,
    },
};

const ShapeCamera = struct {
    comptime object_category: JpObjectCategory = JpObjectCategory.Camera,
    DIRECTION: types.Vec3f32 = types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -1,
    },
    focal_length: f32 = 10,
    field_of_view: f32 = 60,
};

const ShapeLightOmni = struct {
    comptime object_category: JpObjectCategory = JpObjectCategory.Light,
    color: jp_color.JpColor = jp_color.JP_COLOR_GREY,
    decay_rate: LightDecayRate = LightDecayRate.Quadratic,
    intensity: f32 = 0.7,
    exposition: f32 = 0,

    const Self = @This();

    pub fn compute_intensity(self: *Self) f32 {
        return self.intensity * std.math.pow(f32, 2, self.exposition);
    }

    pub fn compute_intensity_from_distance(self: *Self, distance: f32) f32 {
        const intensity = self.compute_intensity();
        var ret: f32 = undefined;
        switch (self.decay_rate) {
            .NoDecay => ret = intensity,
            .Quadratic => {
                ret = intensity / (distance * distance);
            },
        }
        return ret;
    }
};

// ==== HELPERS ==============================================================

pub fn get_normal_at_position(obj: *JpObject, position: types.Vec3f32) types.Vec3f32 {
    var normal: types.Vec3f32 = undefined;
    switch (obj.shape.*) {
        .ImplicitSphere => {
            normal = get_normal_point_at_position_sphere(obj, position);
        },
        .ImplicitPlane => {
            normal = obj.tmatrix.multiply_with_vec3(
                &obj.shape.ImplicitPlane.DIRECTION,
            ).normalize();
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
        // IMPLICIT ----------------------------------------------------------
        .ImplicitPlane => {
            var _actual_shape = try allocator.create(ShapePlane);
            _actual_shape.* = ShapePlane{};
            shape.* = Shape{ .ImplicitPlane = _actual_shape };
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
        .ImplicitPlane => allocator.destroy(jp_object.shape.ImplicitPlane),
        .LightOmni => allocator.destroy(jp_object.shape.LightOmni),
    }
    allocator.destroy(jp_object.shape);
}
