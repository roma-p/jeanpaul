const std = @import("std");
const gpa = std.heap.page_allocator;

const data_color = @import("data_color.zig");
const ControllerAov = @import("controller_aov.zig");

pub const PixelPayload = struct {
    aov_to_color: std.AutoHashMap(ControllerAov.AovStandard, data_color.Color),
    sample_nbr_invert: f32,

    const Self = @This();

    pub fn init(controller_aov: *ControllerAov, sample_nbr_invert: f32) !Self {
        var ret = .{
            .aov_to_color = std.AutoHashMap(ControllerAov.AovStandard, data_color.Color).init(gpa),
            .sample_nbr_invert = sample_nbr_invert,
        };
        for (controller_aov.array_aov_standard.items) |aov| {
            try ret.aov_to_color.put(aov, data_color.COLOR_BlACK);
        }
        return ret;
    }

    pub fn deinit(self: *Self) void {
        self.aov_to_color.deinit();
    }

    pub fn reset(self: Self) void {
        var it = self.aov_to_color.iterator();
        while (it.next()) |item| {
            item.value_ptr.* = data_color.COLOR_BlACK;
        }
    }

    pub fn add_sample_to_aov(
        self: *Self,
        aov_standard: ControllerAov.AovStandard,
        value: data_color.Color,
    ) void {
        const aov_ptr = self.aov_to_color.getPtr(aov_standard); // TODO: check for key existence....
        const sampled_value = value.multiply(self.sample_nbr_invert);
        aov_ptr.?.* = aov_ptr.?.sum_color(sampled_value);
    }
};
