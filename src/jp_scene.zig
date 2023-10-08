const std = @import("std");
const types = @import("types.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

pub const JpScene = struct {
    // CAMERA / SCENE / LIGHT / MATERIAL
    objects: std.ArrayList(*jp_object.JpObject),
    lights: std.ArrayList(*jp_object.JpObject),

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
    };
    return scene;
}

pub fn destroy_scene(scene: *JpScene) void {
    scene.objects.deinit();
    allocator.destroy(scene);
}
