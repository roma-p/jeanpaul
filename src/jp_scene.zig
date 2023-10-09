const std = @import("std");
const types = @import("types.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

pub const JpScene = struct {
    lights: std.ArrayList(*jp_object.JpObject),
    objects: std.ArrayList(*jp_object.JpObject),
    cameras: std.ArrayList(*jp_object.JpObject),
    materials: std.ArrayList(*jp_object.JpObject),
    resolution: types.Vec2u16 = types.Vec2u16{ .x = 640, .y = 480 },

    pub fn add_object(self: *JpScene, obj: *jp_object.JpObject) !void {
        if (obj.object_type != jp_object.JpObjectType.Implicit and
            obj.object_type != jp_object.JpObjectType.Mesh)
        {
            unreachable;
        }
        try self.objects.append(obj);
    }

    pub fn add_light(self: *JpScene, obj: *jp_object.JpObject) !void {
        if (obj.object_type != jp_object.JpObjectType.Light) {
            unreachable;
        }
        try self.lights.append(obj);
    }
};

pub fn create_scene() !*JpScene {
    var scene = try allocator.create(JpScene);
    scene.* = JpScene{
        .objects = try std.ArrayList(*jp_object.JpObject).initCapacity(
            allocator,
            10,
        ),
        .lights = try std.ArrayList(*jp_object.JpObject).initCapacity(
            allocator,
            10,
        ),
        .cameras = try std.ArrayList(*jp_object.JpObject).initCapacity(
            allocator,
            10,
        ),
        .materials = try std.ArrayList(*jp_object.JpObject).initCapacity(
            allocator,
            10,
        ),
    };
    return scene;
}

// pub fn export_as_jpp(path: []const u8) !void {
// }

pub fn destroy_scene(scene: *JpScene) void {
    scene.objects.deinit();
    scene.lights.deinit();
    scene.cameras.deinit();
    scene.materials.deinit();
    allocator.destroy(scene);
}
