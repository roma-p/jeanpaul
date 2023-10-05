const std = @import("std");
const types = @import("types.zig");
const object_module = @import("object.zig");
const material = @import("material.zig");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

pub const Scene = struct {
    // CAMERA / SCENE / LIGHT / MATERIAL
    objects: std.ArrayList(*object_module.Object),
    // camera: std.ArrayList(*object_module.Object),
    pub fn add_object(self: *Scene, obj: *object_module.Object) !void {
        if (obj.object_type != object_module.ObjectType.Implicit and
            obj.object_type != object_module.ObjectType.Mesh)
        {
            unreachable;
        }
        try self.objects.append(obj);
    }
};

pub fn create_scene() !*Scene {
    var scene = try allocator.create(Scene);
    scene.* = Scene{
        .objects = try std.ArrayList(*object_module.Object).initCapacity(
            allocator,
            10,
        ),
    };
    return scene;
}

pub fn destroy_scene(scene: *Scene) void {
    scene.objects.deinit();
    allocator.destroy(scene);
}

test "scene_create_delete_add_obj" {
    var scene = try create_scene();
    var sphere = try object_module.create_sphere();
    try scene.add_object(sphere);
    destroy_scene(scene);
}
