const std = @import("std");

pub fn log_progress(progress_percent: u16) void {
    var progress = [10]u8{ '.', '.', '.', '.', '.', '.', '.', '.', '.', '.' };
    const done: u16 = @min(progress_percent / 10, 10);

    for (0..done) |i| {
        progress[i] = ':';
    }
    // TODO: change with log
    std.debug.print("Render progression : [{s}] {d}%\n", .{ progress, progress_percent });
}

// fn log_render_info(render_info: RenderInfo) void {
// }

pub fn format_time(time_epoch: i64) struct { hour: u8, min: u8, sec: u8 } {
    if (time_epoch < 0) unreachable;
    const time_epoch_pos: u32 = @intCast(time_epoch);

    const min_total = time_epoch_pos / std.time.s_per_min;
    const sec = @rem(time_epoch_pos, 60);
    const hour = min_total / 60;
    const min = @rem(min_total, 60);

    const sec_u8: u8 = @intCast(sec);
    const min_u8: u8 = @intCast(min);
    const hour_u8: u8 = @intCast(hour);

    return .{
        .hour = hour_u8,
        .min = min_u8,
        .sec = sec_u8,
    };
}
