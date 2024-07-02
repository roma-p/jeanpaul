const std = @import("std");
const types = @import("types.zig");
const jp_color = @import("jp_color.zig");
const allocator = std.heap.page_allocator;

const JpManagerObjects = @This();

array_object_to_name: std.ArrayList([4][4]f32),
array_object_to_tmatrix: std.ArrayList([]const u8),

array_object_shape: std.MultiArrayList(Object) = .{},
array_object_light: std.MultiArrayList(Light) = .{},
array_object_camera: std.MultiArrayList(Camera) = .{},

pub fn init() JpManagerObjects {
    return JpManagerObjects{
        .array_object_to_name = std.ArrayList([]const u8).init(allocator),
        .array_object_to_matrix = std.ArrayList([]const u8).init(allocator),
    };
}

pub fn deinit(self: *JpManagerObjects) void {
    self.array_object_shape.deinit(allocator);
    self.array_object_light.deinit(allocator);
    self.array_object_camera.deinit(allocator);
    self.array_object_to_name.deinit();
    self.array_object_to_name.deinit();
    self.* = undefined;
}

pub fn create_light(
        self: *JpManagerObjects,
        material_manager: *JpManagerMaterials, tag: Light.Tag, name: []u8) u16 {
    if (!self._check_is_obj_name_free(name)) return 0;
    const index_name = self.array_object_to_name.len;
    self.array_object_to_name.append(name);

    const index_tmatrix = self.array_object_to_tmatrix.len;
    self.array_object_to_tmatrix.append(types.TRANSFORM_MATRIX_IDENTITY);

    const light_index = self.array_object_light.len;
    self.array_object_light.append(allocator, Light{ .index_name = index_name, .index_tmatrix = index_tmatrix, .tag = tag });
    return light_index;
}

fn _test_evaluate(jpmanager_object: *JpManagerObjects, position: types.Vec3f32, 
        obj_index: u16, mat_index: u16,) bool {

    const material = JpManagerMaterials.array_material[mat_index];
    for (jpmanager_object.array_object_light.items) |light|{

        const pass_ambiant = material._ambiant.multiply_color(light._real_color);

        const ray_dist = get_ray_distant(
            get_position(jpmanager_object.array_object_to_tmatrix[light.index_tmatrix]),
            position,
        );
        if (ray_dist == std.math.MaxInt(u16)) continue;

        // const pass_diffuse = material.
    }

    return false;
}

fn _check_is_obj_name_free(self: *JpManagerObjects, name: []u8) bool {
    for (self.array_object_to_name.items) |_name| {
        if (std.mem.eql(u8, _name, name)) return false;
    }
    return true;
}

pub const Light = struct {
    tag: Tag,

    index_name: u16,
    index_tmatrix: u16,

    intensity: f32 = 0.7,
    exposition: f32 = 0,

    color: jp_color.JpColor = jp_color.JP_COLOR_GREY,
    decay_rate: LightDecayRate = LightDecayRate.Quadratic,

    _real_intensity: f32 = 0,  // intensity * 2^exposition
    _real_color: JpColor = undefined, // color * _real_intensity

    pub const Tag = enum {
        LightPoint,
    };
    pub const LightDecayRate = enum {
        NoDecay,
        Quadratic,
    };
};

pub const Camera = struct {
    index_name: u16,
    tag: Tag,
    index_tmatrix: u16,
    focal_length: f32 = 10,
    field_of_view: f32 = 60,

    const CAMERA_DIRECTION = types.Vec3f32{
        .x = 0,
        .y = 0,
        .z = -1,
    };

    pub const Tag = enum {
        CameraPersp
    };
};

pub const Object = struct {
    tag: Tag,
    data: Data,

    index_material: u16,
    index_tmatrix: u16,

    const IMPLICIT_PLANE_DIRECTION = types.Vec3f32{
        .x = 0,
        .y = 1,
        .z = 0,
    };

    const Tag = enum {
        ImplicitSphere,
        ImplicitPlane,
    };

    const Data = union {
        ImplicitSphere: struct {
            radius: f32 = 10,
        },
    };
};
