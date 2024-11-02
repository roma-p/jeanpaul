const std = @import("std");
const gpa = std.heap.page_allocator;

const definitions = @import("definitions.zig");
const AovStandardEnum = definitions.AovStandardEnum;

const data_color = @import("data_color.zig");
const Color = data_color.Color;
const COLOR_BLACK = data_color.COLOR_BlACK;

const ControllerAov = @import("controller_aov.zig");

pub const ContributionEnum = enum {
    Emission,
    DiffuseDirect,
    DiffuseIndirect,
    SpecularDirect,
    SpecularIndirect,
    Transmission,
};

pub const ScratchBuffer = struct {
    aov_to_color: std.AutoHashMap(AovStandardEnum, Color),
    contribution_buffer: Color,
    contribution_to_color: [@typeInfo(ContributionEnum).Enum.fields.len]Color,
    sample_nbr_invert: f32,
    sample_aa_nbr_invert: f32,
    sample_weight: f32,
    ray_total_length: f32,

    const Self = @This();

    pub fn init(
        controller_aov: *ControllerAov,
        sample_nbr_invert: f32,
        sample_antialiasing_nbr_invert: f32,
    ) !Self {
        var ret = .{
            .aov_to_color = std.AutoHashMap(AovStandardEnum, data_color.Color).init(gpa),
            .contribution_buffer = COLOR_BLACK,
            .contribution_to_color = [1]Color{COLOR_BLACK} ** @typeInfo(ContributionEnum).Enum.fields.len,
            .sample_nbr_invert = sample_nbr_invert,
            .sample_aa_nbr_invert = sample_antialiasing_nbr_invert,
            .sample_weight = sample_nbr_invert * sample_antialiasing_nbr_invert,
            .ray_total_length = 0,
        };
        for (controller_aov.array_aov_standard.items) |aov| {
            try ret.aov_to_color.put(aov, COLOR_BLACK);
            var is_aov_raytraced: bool = true;
            for (definitions.AovStandardNonRaytraced) |item| {
                if (item == aov) {
                    is_aov_raytraced = false;
                }
            }
        }

        return ret;
    }

    pub fn deinit(self: *Self) void {
        self.aov_to_color.deinit();
    }

    pub fn reset(self: *Self) void {
        var it1 = self.aov_to_color.iterator();
        while (it1.next()) |item| {
            item.value_ptr.* = COLOR_BLACK;
        }

        for (&self.contribution_to_color) |*c| {
            c.* = COLOR_BLACK;
        }

        self.contribution_buffer = COLOR_BLACK;

        self.ray_total_length = 0;
    }

    // -- AOV handling --

    pub fn get_aov(self: *Self, aov_standard: AovStandardEnum) ?data_color.Color {
        return self.aov_to_color.get(aov_standard);
    }

    pub fn set_aov(
        self: *Self,
        aov_standard: AovStandardEnum,
        value: data_color.Color,
    ) void {
        if (!self.check_has_aov(aov_standard)) return;
        const aov_ptr = self.aov_to_color.getPtr(aov_standard);
        aov_ptr.?.* = value;
    }

    pub fn check_has_aov(self: *Self, aov_standard: AovStandardEnum) bool {
        return (self.aov_to_color.get(aov_standard) != null);
    }

    pub fn add_aa_sample_to_aov(
        self: *Self,
        aov_standard: AovStandardEnum,
        value: data_color.Color,
    ) void {
        if (!self.check_has_aov(aov_standard)) return;
        const aov_ptr = self.aov_to_color.getPtr(aov_standard);
        const sampled_value = value.product(self.sample_aa_nbr_invert);
        aov_ptr.?.* = aov_ptr.?.sum_color(sampled_value);
    }

    // -- Contribution handling --

    pub fn get_contribution(self: *Self, contribution_id: ContributionEnum) Color {
        return self.contribution_to_color[@intFromEnum(contribution_id)];
    }

    pub fn add_to_contribution_buffer(
        self: *Self,
        color: Color,
    ) void {
        if (self.contribution_buffer.check_is_equal(COLOR_BLACK)) {
            self.contribution_buffer = data_color.COLOR_WHITE;
        }
        self.contribution_buffer = self.contribution_buffer.multiply_color(color);
    }

    pub fn reset_contribution_buffer(self: *Self) void {
        self.contribution_buffer = COLOR_BLACK;
    }

    pub fn dump_contribution_buffer(self: *Self, contribution_id: ContributionEnum) void {
        const i = @intFromEnum(contribution_id);
        const value = self.contribution_buffer.product(self.sample_weight);
        self.contribution_to_color[i] = self.contribution_to_color[i].sum_color(value);
    }

    pub fn log_debug_contribution(self: *Self) void {
        var i: usize = 0;
        std.debug.print("current contribution is: \n", .{});
        while (i < self.contribution_to_color.len) : (i += 1) {
            const contribution = self.contribution_to_color[i];
            const enum_name: ContributionEnum = @enumFromInt(i);
            std.debug.print(
                "{?} : r:{d}, g:{d}, b:{d}\n",
                .{ enum_name, contribution.r, contribution.g, contribution.b },
            );
        }
        std.debug.print("\n", .{});
    }

    // -- Contribution to Aov --

    pub fn dump_contributions_to_aovs(self: *Self) void {
        const contribution_emission = self.get_contribution(ContributionEnum.Emission);
        const contribution_diffuse_direct = self.get_contribution(ContributionEnum.DiffuseDirect);
        const contribution_diffuse_indirect = self.get_contribution(ContributionEnum.DiffuseIndirect);
        const contribution_specular_direct = self.get_contribution(ContributionEnum.SpecularDirect);
        const contribution_specular_indirect = self.get_contribution(ContributionEnum.SpecularIndirect);
        const contribution_transmission = self.get_contribution(ContributionEnum.Transmission);

        var beauty = COLOR_BLACK;

        beauty.sum_to_color(contribution_emission);
        beauty.sum_to_color(contribution_diffuse_direct);
        beauty.sum_to_color(contribution_diffuse_indirect);
        beauty.sum_to_color(contribution_specular_direct);
        beauty.sum_to_color(contribution_specular_indirect);
        beauty.sum_to_color(contribution_transmission);

        var direct = COLOR_BLACK;
        direct.sum_to_color(contribution_emission);
        direct.sum_to_color(contribution_diffuse_direct);
        direct.sum_to_color(contribution_specular_direct);
        direct.sum_to_color(contribution_transmission);

        var indirect = COLOR_BLACK;
        indirect.sum_to_color(contribution_diffuse_indirect);
        indirect.sum_to_color(contribution_specular_indirect);

        self.set_aov(AovStandardEnum.Beauty, beauty);
        self.set_aov(AovStandardEnum.Direct, direct);
        self.set_aov(AovStandardEnum.Indirect, indirect);
        self.set_aov(
            AovStandardEnum.Diffuse,
            contribution_diffuse_direct.sum_color(contribution_diffuse_indirect),
        );
        self.set_aov(
            AovStandardEnum.Specular,
            contribution_specular_direct.sum_color(contribution_specular_indirect),
        );
        self.set_aov(AovStandardEnum.Emission, contribution_emission);
        self.set_aov(AovStandardEnum.DiffuseDirect, contribution_diffuse_direct);
        self.set_aov(AovStandardEnum.DiffuseIndirect, contribution_diffuse_indirect);
        self.set_aov(AovStandardEnum.SpecularDirect, contribution_specular_direct);
        self.set_aov(AovStandardEnum.SpecularIndirect, contribution_specular_indirect);
        self.set_aov(AovStandardEnum.Transmission, contribution_transmission);
    }
};
