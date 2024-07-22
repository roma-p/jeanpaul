const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const ControllerObject = @import("controller_object.zig");
const ControllerAov = @import("controller_aov.zig");
const RenderSettings = @import("render_settings.zig");

pub const ControllerScene = @This();

controller_object: ControllerObject,
controller_aov: ControllerAov,
render_settings: RenderSettings,

pub fn init() ControllerScene {
    return .{
        .controller_object = ControllerObject.init(),
        .controller_aov = ControllerAov.init(),
        .render_settings = RenderSettings.create_with_default_value(),
    };
}

pub fn deinit(self: *ControllerScene) void {
    self.controller_object.deinit();
    self.controller_aov.deinit();
}

test "cs_init_deinit" {
    var controller = ControllerScene.init();
    controller.deinit();
}
