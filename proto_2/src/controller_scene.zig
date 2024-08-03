const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const RenderSettings = @import("data_render_settings.zig");
const data_handle = @import("data_handle.zig");

const ControllerMaterial = @import("controller_material.zig");
const ControllerObject = @import("controller_object.zig");
const ControllerAov = @import("controller_aov.zig");

pub const ControllerScene = @This();

controller_material: ControllerMaterial,
controller_object: ControllerObject,
controller_aov: ControllerAov,
render_settings: RenderSettings,

pub fn init() !ControllerScene {
    var ret = ControllerScene{
        .controller_material = ControllerMaterial.init(),
        .controller_object = ControllerObject.init(),
        .controller_aov = ControllerAov.init(),
        .render_settings = RenderSettings.create_with_default_value(),
    };
    _ = try ret.controller_material.add_material("default");
    return ret;
}

pub fn deinit(self: *ControllerScene) void {
    self.controller_material.deinit();
    self.controller_object.deinit();
    self.controller_aov.deinit();
}

test "cs_init_deinit" {
    var controller = try ControllerScene.init();
    controller.deinit();
}
