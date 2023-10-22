const std = @import("std");
const types = @import("types.zig");
const jp_color = @import("jp_color.zig");
const stdout = std.io.getStdOut().writer();
const allocator = std.heap.page_allocator;

pub const JpImg = struct {
    width: u16 = undefined,
    height: u16 = undefined,
    r: [][]f32 = undefined,
    g: [][]f32 = undefined,
    b: [][]f32 = undefined,
    a: [][]f32 = undefined,

    const Self = @This();

    // axis used by the image are:
    //
    //  y
    //  ^
    //  |
    //  * -> x
    pub fn new(width: u16, height: u16) !*JpImg {
        const img = try allocator.create(JpImg);
        errdefer allocator.destroy(img);

        img.* = JpImg{
            .width = width,
            .height = height,
            .r = try types.matrix_f32_create(width, height),
            .g = try types.matrix_f32_create(width, height),
            .b = try types.matrix_f32_create(width, height),
            .a = try types.matrix_f32_create(width, height),
        };
        return img;
    }

    pub fn delete(self: *Self) void {
        types.matrix_f32_delete(&self.r);
        types.matrix_f32_delete(&self.g);
        types.matrix_f32_delete(&self.b);
        types.matrix_f32_delete(&self.a);
        allocator.destroy(self);
    }

    // axis to print on console are.
    //
    //  * -> x
    //  |
    //  v y
    pub fn image_prompt_to_console(self: *Self) !void {
        var _x: u16 = 0;
        var _y: u16 = undefined;
        while (_x < self.width) : (_x += 1) {
            _y = self.height - 1;
            while (_y != 0) : (_y -= 1) {
                var value: f32 = self.r[_x][_y];
                var c: u8 = undefined;
                if (value == 0) {
                    c = '.';
                } else {
                    c = 'x';
                }
                try stdout.print("{c}", .{c});
            }
            try stdout.print("\n", .{});
        }
    }

    // axis on ppm are.
    //
    //  * -> x
    //  |
    //  v y
    pub fn image_write_to_ppm(self: *Self, filename: []const u8) !void {
        const file = try std.fs.cwd().createFile(
            filename,
            .{ .read = true },
        );
        defer file.close();

        const header = try std.fmt.allocPrint(
            allocator,
            "P3\n{d} {d}\n255\n",
            .{ self.width, self.height },
        );
        try file.writeAll(header);
        defer allocator.free(header);

        var _x: u16 = undefined;
        var _y: u16 = self.height;

        while (_y > 0) : (_y -= 1) {
            _x = 0;
            while (_x < self.width) : (_x += 1) {
                const line = try std.fmt.allocPrint(
                    allocator,
                    "\n{} {} {}",
                    .{
                        jp_color.cast_jp_color_to_u8(self.r[_x][_y - 1]),
                        jp_color.cast_jp_color_to_u8(self.g[_x][_y - 1]),
                        jp_color.cast_jp_color_to_u8(self.b[_x][_y - 1]),
                    },
                );
                try file.writeAll(line);
                defer allocator.free(line);
            }
        }
    }

    pub fn image_draw_at_px(self: *Self, x: u16, y: u16, color: jp_color.JpColor) !void {
        self.r[x][y] = color.r;
        self.g[x][y] = color.g;
        self.b[x][y] = color.b;
    }
};
