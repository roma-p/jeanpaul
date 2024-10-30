const std = @import("std");
const gpa = std.heap.page_allocator;
const RndGen = std.rand.DefaultPrng;

const renderer_scratch_buffer = @import("renderer_scratch_buffer.zig");

const ControllerAov = @import("controller_aov.zig");
const ScratchBuffer = renderer_scratch_buffer.ScratchBuffer;

pub const RenderDataPerThread = struct {
    rnd: RndGen,
    scratch_buffer: ScratchBuffer,

    const Self = @This();

    pub fn init(
        controller_aov: *ControllerAov,
        sample_nbr_invert: f32,
        sample_antialiasing_nbr_invert: f32,
        seed: usize,
    ) !Self {
        return .{
            .scratch_buffer = try ScratchBuffer.init(
                controller_aov,
                sample_nbr_invert,
                sample_antialiasing_nbr_invert,
            ),
            .rnd = RndGen.init(seed),
        };
    }
};
