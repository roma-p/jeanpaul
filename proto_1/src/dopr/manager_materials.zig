const std = @import("std");
const jp_color = @import("jp_color.zig");
const allocator = std.heap.page_allocator;

const JpManagerMaterial = @This();

// TODO: allocator;

array_material: std.MultiArrayList(Material) = .{},
array_material_pbr: std.MultiArrayList(MatPBR) = .{},
array_material_alpha: std.MultiArrayList(MatAlpha) = .{},
array_material_to_name: std.ArrayList([]const u8),

pub fn init() JpManagerMaterial {
    return JpManagerMaterial{
        .array_material_to_name = std.ArrayList([]const u8).init(allocator),
    };
}

pub fn deinit(self: *JpManagerMaterial) void {
    self.array_material.deinit(allocator);
    self.array_material_pbr.deinit(allocator);
    self.array_material_alpha.deinit(allocator);
    self.array_material_to_name.deinit();
    self.* = undefined;
}

const Material = struct {
    tag: Tag,
    extra_index: u32,
};

const Tag = enum { PBR, ALPHA, NORMAL };

const MatPBR = struct {
    kd_ambiant: f32 = 0.06,
    kd_color: jp_color.JpColor = jp_color.JP_COLOR_DEFAULT,
    kd_intensity: f32 = 0.7,

    _albedo: jp_color.JpColor = 0, // kd_intensity * kd_color
    _ambiant: jp_color.JpColor = 0, // kd_ambiant * kd_color
};

const MatAlpha = struct {
    color: jp_color.JpColor = jp_color.JP_COLOR_DEFAULT,
};

fn _check_is_mat_name_free(self: *JpManagerMaterial, name: []u8) bool {
    for (self._array_material_to_name.items) |_name| {
        if (std.mem.eql(u8, _name, name)) return false;
    }
    return true;
}

test "MaterialSubSystem.new_material" {
    _ = false;
    var lul = JpManagerMaterial.init();
    try lul.array_material.append(allocator, .{
        .tag = Tag.PBR,
        .extra_index = 0,
    });
    lul.deinit();
}
