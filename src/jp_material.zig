const std = @import("std");
const allocator = std.heap.page_allocator;
const types = @import("types.zig");
const jp_color = @import("jp_color.zig");

// ==== Constants ============================================================

pub const MaterialTypeId = enum {
    Lambert,
};

const Material = union(MaterialTypeId) {
    Lambert: *MatLambert,
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
    kd_color: jp_color.JpColor = jp_color.JP_COLOR_DEFAULT,
    //FIXME: kd_intensity not used!
    kd_intensity: f32 = 0.7,
};

// ==== HELPERS ==============================================================

pub fn create_default_colored_material(color: jp_color.JpColor) !*JpMaterial {
    var material = try JpMaterial.new("default", MaterialTypeId.Lambert);
    material.mat.Lambert.kd_color = color;
    return material;
}
