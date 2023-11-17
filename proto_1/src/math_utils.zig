pub fn solve_quadratic(a: f32, b: f32, c: f32, x0: *f32, x1: *f32) !bool {
    const discr: f64 = @as(f64, b) * @as(f64, b) - 4 * @as(f64, a) * @as(f64, c);
    if (discr < 0) {
        return false;
    } else if (discr == 0) {
        var ret: f32 = -0.5 * b / a;
        x0.* = ret;
        x1.* = ret;
    } else {
        var q: f64 = undefined;
        if (b > 0) {
            q = -0.5 * (b + @sqrt(discr));
        } else {
            q = -0.5 * (b - @sqrt(discr));
        }
        var q_32: f32 = @floatCast(q);
        x0.* = q_32 / a;
        x1.* = c / q_32;
    }
    return true;
}
