const std = @import("std");
const types = @import("types.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

// TODO: pas de séparation entre les objets, materiaux et caméras...
// et donc! light hittable comme les autres! changer l'algo pour ça...

pub const JpSceneError = error{
    AllocationError,
    NameNotAvailable,
    ObjectNotFound,
    MaterialNotFound,
};

pub const JpScene = struct {
    objects: std.ArrayList(*jp_object.JpObject),
    materials: std.ArrayList(*jp_material.JpMaterial),
    resolution: types.Vec2u16 = types.Vec2u16{ .x = 640, .y = 480 },
    render_camera: jp_object.JpObject,

    const Self = @This();

    pub fn new() !*Self {
        var scene = try allocator.create(Self);
        scene.* = JpScene{
            .objects = try std.ArrayList(*jp_object.JpObject).initCapacity(allocator, 10),
            .materials = try std.ArrayList(*jp_material.JpMaterial).initCapacity(allocator, 10),
            .render_camera = undefined,
        };
        return scene;
    }

    pub fn delete(self: *Self) void {
        self.objects.deinit();
        self.materials.deinit();
        allocator.destroy(self);
    }

    pub fn add_object(self: *Self, obj: *jp_object.JpObject) !void {
        if (!self._check_object_name_free(obj.name)) return JpSceneError.NameNotAvailable;
        self.objects.append(obj) catch return JpSceneError.AllocationError;
    }

    pub fn create_object(
        self: *Self,
        name: []const u8,
        shape_type_id: jp_object.ShapeTypeId,
    ) JpSceneError!*jp_object.JpObject {
        if (!self._check_object_name_free(name)) return JpSceneError.NameNotAvailable;

        var object = jp_object.JpObject.new(name, shape_type_id) catch return JpSceneError.AllocationError;
        errdefer object.delete();

        self.objects.append(object) catch return JpSceneError.AllocationError;
        return object;
    }

    pub fn delete_object(self: *Self, obj: *jp_object.JpObject) void {
        for (self.objects.items, 0..) |o, i| {
            if (o == obj) {
                _ = self.objects.swapRemove(i);
                obj.delete();
                return;
            }
        }
    }

    pub fn add_material(self: *Self, material: *jp_material.JpMaterial) JpSceneError!void {
        if (!self._check_material_name_free(material.name)) return JpSceneError.NameNotAvailable;
        self.materials.append(material) catch return JpSceneError.AllocationError;
    }

    pub fn create_material(
        self: *Self,
        name: []const u8,
        material_type_id: jp_material.MaterialTypeId,
    ) JpSceneError!*jp_material.JpMaterial {
        if (!self._check_material_name_free(name)) return JpSceneError.NameNotAvailable;

        var material = jp_material.JpMaterial.new(
            name,
            material_type_id,
        ) catch return JpSceneError.AllocationError;
        errdefer material.delete();

        try self.materials.append(material) catch return JpSceneError.AllocationError;
        return material;
    }

    pub fn delete_material(self: *Self, material: *jp_material.JpMaterial) void {
        for (self.materials.items, 0..) |m, i| {
            if (m == material) {
                _ = Self.materials.swapRemove(i);
                material.delete();
                return;
            }
        }
    }

    fn _check_material_name_free(self: *Self, name: []const u8) bool {
        for (self.materials.items) |mat| {
            if (std.mem.eql(u8, mat.name, name)) {
                return false;
            }
        }
        return true;
    }

    fn _check_object_name_free(self: *Self, name: []const u8) bool {
        for (self.objects.items) |object| {
            if (std.mem.eql(u8, object.name, name)) {
                return false;
            }
        }
        return true;
    }
};

// pub fn export_as_jpp(path: []const u8) !void {
// }
