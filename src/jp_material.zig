const std = @import("std");
const allocator = std.heap.page_allocator;
const types = @import("types.zig");
const jp_color = @import("jp_color.zig");

// ==== Constants ============================================================

pub const MaterialTypeId = enum {
    Lambert,
};

const Material = union(enum) {
    Lambert: *MatLambert,
};

// ==== JpMaterial ===========================================================

pub const JpMaterial = struct {
    mat: *Material = undefined,
    name: []const u8 = undefined,

    const Self = @This();

    pub fn new(name: []const u8, material_type_id: MaterialTypeId) !*Self {
        var jpmat = try allocator.create(Self);
        var mat = try allocator.create(Material);
        switch (material_type_id) {
            .Lambert => {
                var actual_mat = try allocator.create(MatLambert);
                actual_mat.* = MatLambert{};
                mat.* = Material{ .Lambert = actual_mat };
            },
        }
        jpmat.mat = mat;
        jpmat.name = name;
        return jpmat;
    }

    pub fn delete(self: *Self) void {
        switch (self.mat.*) {
            .Lambert => allocator.destroy(self.mat.Lambert),
        }
        allocator.destroy(self.mat);
        allocator.destroy(self);
    }
};

// ==== Material Definition ==================================================

pub const MatLambert = struct {
    diffuse: jp_color.JpColor = jp_color.JP_COLOR_DEFAULT,
};

// ==== HELPERS ==============================================================

pub fn create_default_colored_material(color: jp_color.JpColor) !*JpMaterial {
    var material = try JpMaterial.new("default", MaterialTypeId.Lambert);
    material.mat.Lambert.diffuse = color;
    return material;
}
