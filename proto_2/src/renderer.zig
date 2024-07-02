const std = @import("std");
const ControllereScene = @import("controller_scene.zig");
const ControllerImg = @import("controller_img.zig");

const Renderer = @This();

controller_scene: *ControllereScene,
controller_img: ControllerImg,

pub fn init(controller_scene: *ControllereScene) Renderer {
    return .{
        .controller_scene = controller_scene,
        .controller_img = ControllerImg.init(
            controller_scene.render_settings.width,
            controller_scene.render_settings.height,
        ),
    };
    // missing: add aov. aov model?
}

pub fn deinit(self: *Renderer) void {
    self.controller_img.deinit();
}

test "renderer_init_deinit" {
    var controller_scene = ControllereScene.init();
    var renderer = Renderer.init(&controller_scene);
    renderer.deinit();
    controller_scene.deinit();
}
