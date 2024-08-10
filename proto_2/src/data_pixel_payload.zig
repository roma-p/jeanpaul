const std = @import("std");
const gpa = std.heap.page_allocator;

const definitions = @import("definitions.zig");
const AovStandardEnum = definitions.AovStandardEnum;

const data_color = @import("data_color.zig");

const ControllerAov = @import("controller_aov.zig");

pub const PixelPayload = struct {
    aov_to_color: std.AutoHashMap(AovStandardEnum, data_color.Color),
    aov_to_color_buffer: std.AutoHashMap(AovStandardEnum, data_color.Color),
    sample_nbr_invert: f32,
    ray_total_length: f32,

    const Self = @This();

    pub fn init(controller_aov: *ControllerAov, sample_nbr_invert: f32) !Self {
        var ret = .{
            .aov_to_color = std.AutoHashMap(AovStandardEnum, data_color.Color).init(gpa),
            .aov_to_color_buffer = std.AutoHashMap(AovStandardEnum, data_color.Color).init(gpa),
            .sample_nbr_invert = sample_nbr_invert,
            .ray_total_length = 0,
        };
        for (controller_aov.array_aov_standard.items) |aov| {
            try ret.aov_to_color.put(aov, data_color.COLOR_BlACK);
            var is_aov_raytraced: bool = true;
            for (definitions.AovStandardNonRaytraced) |item| {
                if (item == aov) {
                    is_aov_raytraced = false;
                }
            }
            if (is_aov_raytraced) {
                try ret.aov_to_color_buffer.put(aov, data_color.COLOR_BlACK);
            }
        }
        return ret;
    }

    pub fn deinit(self: *Self) void {
        self.aov_to_color.deinit();
        self.aov_to_color_buffer.deinit();
    }

    pub fn reset(self: *Self) void {
        var it1 = self.aov_to_color.iterator();
        while (it1.next()) |item| {
            item.value_ptr.* = data_color.COLOR_BlACK;
        }
        var it2 = self.aov_to_color_buffer.iterator();
        while (it2.next()) |item| {
            item.value_ptr.* = data_color.COLOR_BlACK;
        }
        self.ray_total_length = 0;
    }

    pub fn add_sample_to_aov(
        self: *Self,
        aov_standard: AovStandardEnum,
        value: data_color.Color,
    ) void {
        if (!self.check_has_aov(aov_standard)) return;
        const aov_ptr = self.aov_to_color.getPtr(aov_standard); // TODO: check for key existence....
        const sampled_value = value.product(self.sample_nbr_invert);
        aov_ptr.?.* = aov_ptr.?.sum_color(sampled_value);
    }

    pub fn check_has_aov(self: *Self, aov_standard: AovStandardEnum) bool {
        // TODO: syntaxic sugar for this...
        const v = self.aov_to_color.get(aov_standard);
        if (v == null) {
            return false;
        } else {
            return true;
        }
    }

    pub fn set_aov_buffer_value(
        self: *Self,
        aov_standard: AovStandardEnum,
        color: data_color.Color,
    ) void {
        if (!self.check_has_aov(aov_standard)) return;
        const aov_ptr = self.aov_to_color_buffer.getPtr(aov_standard);
        aov_ptr.?.* = color;
    }

    pub fn copy_aov_buffer_value(
        self: *Self,
        in_aov_standard: AovStandardEnum,
        out_aov_standard: AovStandardEnum,
    ) void {
        if (!self.check_has_aov(in_aov_standard)) return;
        if (!self.check_has_aov(out_aov_standard)) return;
        const in_aov_ptr = self.aov_to_color_buffer.getPtr(in_aov_standard);
        const out_aov_ptr = self.aov_to_color_buffer.getPtr(out_aov_standard);
        out_aov_ptr.?.* = in_aov_ptr.?.*;
    }

    pub fn product_aov_buffer_value(
        self: *Self,
        aov_standard: AovStandardEnum,
        color: data_color.Color,
    ) void {
        const aov_ptr = self.aov_to_color_buffer.getPtr(aov_standard).?;
        aov_ptr.* = aov_ptr.*.multiply_color(color);
    }

    pub fn dump_buffer_to_aov(self: *Self) void {
        var it = self.aov_to_color_buffer.iterator();
        while (it.next()) |item| {
            self.add_sample_to_aov(item.key_ptr.*, item.value_ptr.*);
        }
    }
};
