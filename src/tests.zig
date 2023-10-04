const std = @import("std");

// comptime {
//     _ = @import("rgba_img.zig");
//     _ = @import("draw_2d_shapes.zig");
//     _ = @import("obj_primitives.zig");
//     // _ = @import("camera.zig");
// }

pub const r = @import("rgba_img.zig");
pub const d = @import("draw_2d_shapes.zig");
pub const o = @import("obj_primitives.zig");
// pub const c = @import("camera.zig");

test {
    std.testing.refAllDecls(@This());
}
