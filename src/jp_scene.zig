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

    const Self = @This();

    pub fn new() !*Self {
        var scene = try allocator.create(Self);
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

    pub fn delete(self: *Self) void {
        self.objects.deinit();
        self.lights.deinit();
        self.cameras.deinit();
        self.materials.deinit();
        allocator.destroy(self);
    }

    pub fn add_object(self: *Self, obj: *jp_object.JpObject) !void {
        if (obj.object_type != jp_object.JpObjectType.Implicit and
            obj.object_type != jp_object.JpObjectType.Mesh)
        {
            unreachable;
        }
        try self.objects.append(obj);
    }

    pub fn add_light(self: *Self, obj: *jp_object.JpObject) !void {
        if (obj.object_type != jp_object.JpObjectType.Light) {
            unreachable;
        }
        try self.lights.append(obj);
    }
};

// pub fn export_as_jpp(path: []const u8) !void {
// }
