const std = @import("std");
const allocator = std.heap.page_allocator;
const types = @import("types.zig");
const jp_color = @import("jp_color.zig");

// ==== Constants ============================================================

pub const MaterialTypeId = enum {
    Lambert,
    AovAlpha,
    AovNormal,
};

pub const MaterialTypeIdArray = [_]MaterialTypeId{
    .Lambert,
    .AovAlpha,
    .AovNormal,
};

const Material = union(MaterialTypeId) {
    Lambert: *MatLambert,
    AovAlpha: *MatAovAlpha,
    AovNormal: *MatAovNormal,
};

// ==== JpMaterial ===========================================================

pub const JpMaterial = struct {
    mat: *Material = undefined,
    name: []const u8 = undefined,

    const Self = @This();

    pub fn new(name: []const u8, material_type_id: MaterialTypeId) !*Self {
        var jpmat = try allocator.create(Self);
        errdefer allocator.destroy(jpmat);

        var mat = try allocator.create(Material);
        errdefer allocator.destroy(mat);

        switch (material_type_id) {
            .Lambert => {
                var actual_mat = try allocator.create(MatLambert);
                errdefer allocator.destroy(actual_mat);
                actual_mat.* = MatLambert{};
                mat.* = Material{ .Lambert = actual_mat };
            },
            .AovAlpha => {
                var actual_mat = try allocator.create(MatAovAlpha);
                errdefer allocator.destroy(actual_mat);
                actual_mat.* = MatAovAlpha{};
                mat.* = Material{ .AovAlpha = actual_mat };
            },
            .AovNormal => {
                var actual_mat = try allocator.create(MatAovNormal);
                errdefer allocator.destroy(actual_mat);
                actual_mat.* = MatAovNormal{};
                mat.* = Material{ .AovNormal = actual_mat };
            },
        }
        jpmat.mat = mat;
        jpmat.name = name;
        return jpmat;
    }

    pub fn delete(self: *Self) void {
        switch (self.mat.*) {
            .Lambert => allocator.destroy(self.mat.Lambert),
            .AovAlpha => allocator.destroy(self.mat.AovAlpha),
            .AovNormal => allocator.destroy(self.mat.AovNormal),
        }
        allocator.destroy(self.mat);
        allocator.destroy(self);
    }
};

// ==== Material Definition ==================================================

pub const MatLambert = struct {
    kd_color: jp_color.JpColor = jp_color.JP_COLOR_DEFAULT,
    kd_intensity: f32 = 0.7,
};

pub const MatAovAlpha = struct {
    color: jp_color.JpColor = jp_color.JP_COLOR_DEFAULT,
};

pub const MatAovNormal = struct {};

// ==== HELPERS ==============================================================

pub fn create_default_colored_material(color: jp_color.JpColor) !*JpMaterial {
    var material = try JpMaterial.new("default", MaterialTypeId.Lambert);
    material.mat.Lambert.kd_color = color;
    return material;
}
