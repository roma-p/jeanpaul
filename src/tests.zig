const std = @import("std");

comptime {
    _ = @import("test_draw_2d.zig");
    _ = @import("test_jp_img.zig");
    _ = @import("test_jp_object.zig");
    _ = @import("test_jp_scene.zig");
    _ = @import("test_render.zig");
    _ = @import("test_jp_ray.zig");
    _ = @import("test_jpp_format.zig");
    _ = @import("test_jpp_parser.zig");
}

test {
    std.testing.refAllDecls(@This());
}
