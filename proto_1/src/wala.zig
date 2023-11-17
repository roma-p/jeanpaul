const std = @import("std");
const jpp_parser = @import("jpp_parser.zig");
const render = @import("render.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    const args = try std.process.argsAlloc(gpa);

    const command = args[1];

    if (std.mem.eql(u8, command, "jpp")) {
        if (args.len < 4) {
            std.log.err(
                "wrong format for jpp command, expected: wala jpp file.jpp img.ppm",
                .{},
            );
            return;
        }
        const scene = try jpp_parser.JppParser.parse(args[2]);
        try render.render_to_path(scene.render_camera, scene, args[3]);
    } else {
        std.log.warn("unknown command: {s}\n", .{command});
    }
}
