const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const data_color = @import("data_color.zig");
const data_handles = @import("data_handle.zig");

const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");

const Vec3f32 = maths_vec.Vec3f32;
const TMatrix = maths_tmat.TMatrix;
const Color = data_color.Color;

pub const ControllerMaterial = @This();

const ErrorControllerMaterial = error{ NameAlreadyTaken, InvalidHandle };

// "entities"
array_material: std.ArrayList(?Material),

// "components"
array_name: std.ArrayList(?[]const u8),

pub fn init() ControllerMaterial {
    return .{
        .array_name = std.ArrayList(?[]const u8).init(gpa),
        .array_material = std.ArrayList(?Material).init(gpa),
    };
}

pub fn deinit(self: *ControllerMaterial) void {
    self.array_name.deinit();
    self.array_material.deinit();
}

pub const Material = struct {
    base: f32 = 0.7,
    base_color: Color = data_color.COLOR_GREY,
};

pub fn add_material(
    self: *ControllerMaterial,
    name: []const u8,
) !data_handles.HandleMaterial {
    for (self.array_name.items) |v| {
        if (v == null) continue;
        if (std.mem.eql(u8, v.?, name)) {
            return ErrorControllerMaterial.NameAlreadyTaken;
        }
    }
    const idx = self.array_material.items.len;
    try self.array_name.append(name);
    try self.array_material.append(Material{});
    return data_handles.HandleMaterial{ .idx = idx };
}

pub fn get_mat_pointer(
    self: *ControllerMaterial,
    handle: data_handles.HandleMaterial,
) ErrorControllerMaterial!*Material {
    if (handle.idx > self.array_env.items.len) {
        return ErrorControllerMaterial.InvalidHandle;
    }
    if (self.array_material.items[handle.idx]) |*v| {
        return v;
    } else {
        return ErrorControllerMaterial.InvalidHandle;
    }
}
