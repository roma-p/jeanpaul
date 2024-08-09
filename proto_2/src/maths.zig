const std = @import("std");
const gpa = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

const constants = @import("constants.zig");

/// returns: number of solution (0, 1, 2), and two pottential solution. (0 default).
/// if two smaller solution first.
pub fn solve_quadratic(a: f32, b: f32, c: f32) !struct { u2, f32, f32 } {
    const discr: f64 = @as(f64, b) * @as(f64, b) - 4 * @as(f64, a) * @as(f64, c);
    if (discr < 0) {
        return .{ 0, 0, 0 };
    } else if (discr == 0) {
        const ret: f32 = -0.5 * b / a;
        return .{ 1, ret, 0 };
    } else {
        var q: f64 = undefined;
        if (b > 0) {
            q = -0.5 * (b + @sqrt(discr));
        } else {
            q = -0.5 * (b - @sqrt(discr));
        }
        const q_32: f32 = @floatCast(q);
        const x0: f32 = q_32 / a;
        const x1: f32 = c / q_32;
        if (x0 < x1) return .{ 2, x0, x1 } else return .{ 2, x1, x0 };
    }
}

pub fn check_almost_equal(a: f32, b: f32) bool {
    const tmp = @abs(a - b);
    return (tmp <= constants.EPSILON);
}

// TESTS ---------------------------------------------------------------------

test "u_check_almost_equal" {
    const a_1: f32 = 1;
    const b_1: f32 = 1;
    try std.testing.expectEqual(true, check_almost_equal(a_1, b_1));

    const a_2: f32 = 1;
    const b_2: f32 = 2;
    try std.testing.expectEqual(false, check_almost_equal(a_2, b_2));

    const a_3: f32 = -constants.EPSILON;
    const b_3: f32 = 0;
    try std.testing.expectEqual(true, check_almost_equal(a_3, b_3));

    const a_4: f32 = 0;
    const b_4: f32 = constants.EPSILON;
    try std.testing.expectEqual(true, check_almost_equal(a_4, b_4));
}

test "u_solve_quadratic" {
    const out_1 = try solve_quadratic(1, -5, 6);
    try std.testing.expectEqual(2, out_1.@"0");
    try std.testing.expectEqual(2, out_1.@"1");
    try std.testing.expectEqual(3, out_1.@"2");

    const out_2 = try solve_quadratic(1, -4, 4);
    try std.testing.expectEqual(1, out_2.@"0");
    try std.testing.expectEqual(2, out_2.@"1");
    try std.testing.expectEqual(0, out_2.@"2");

    const out_3 = try solve_quadratic(1, 1, 1);
    try std.testing.expectEqual(0, out_3.@"0");
    try std.testing.expectEqual(0, out_3.@"1");
    try std.testing.expectEqual(0, out_3.@"2");
}
