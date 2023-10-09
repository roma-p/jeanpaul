const std = @import("std");
const allocator = std.heap.page_allocator;
const types = @import("types.zig");
const jp_color = @import("jp_color.zig");

pub const JpMaterial = struct {
    mat: *Material = undefined,
};

const Material = union(enum) {
    Lambert: *MatLambert,
};

pub const MatLambert = struct {
    diffuse: jp_color.JpColor = jp_color.JP_COLOR_DEFAULT,
};

pub fn create_material_lambert() !*JpMaterial {
    var lambert = try allocator.create(MatLambert);
    lambert.* = MatLambert{};
    var mat_wrapper = try allocator.create(Material);
    mat_wrapper.* = Material{ .Lambert = lambert };
    var mat = try allocator.create(JpMaterial);
    mat.* = JpMaterial{
        .mat = mat_wrapper,
    };
    return mat;
}

pub fn delete_material(material: *JpMaterial) void {
    switch (material.mat.*) {
        .Lambert => allocator.destroy(material.mat.Lambert),
    }
    allocator.destroy(material.mat);
    allocator.destroy(material);
}

pub fn create_default_colored_material(color: jp_color.JpColor) !*JpMaterial {
    var material = try create_material_lambert();
    material.mat.Lambert.diffuse = color;
    return material;
}
