const std = @import("std");
const gpa = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

pub const JP_EPSILON: f32 = 0.0000001;

// -- MATRIX -----------------------------------------------------------------

// -- Vec3f32 ----------------------------------------------------------------

// only a namseapce of func...
pub const TMatrix = struct {};
