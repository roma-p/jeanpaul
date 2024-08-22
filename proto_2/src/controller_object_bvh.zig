const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const ControllerObject = @import("controller_object.zig");

const definitions = @import("definitions.zig");

const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");
const maths_bbox = @import("maths_bbox.zig");

const Vec3f32 = maths_vec.Vec3f32;
const Axis = maths_vec.Axis;
const BoundingBox = maths_bbox.BoundingBox;

const utils_geo = @import("utils_geo.zig");

bvh_method: BvhMethod,
infinite_shape: std.ArrayList(usize),

_tmp_shape_bounding_box_slice: std.ArrayList(ShapeBoundingBox),
_tmp_bhv_tree: std.ArrayList(BvhBuildNode),

const ControllerObjectBVH = @This();

pub const BvhMethod = enum {
    EqualSize,
    SAH, // Surface Area Heuristics
};

pub const BvhNode = struct {
    bbox: BoundingBox,
    next: union {
        idx_shape: usize,
        idx_second_children: usize,
    },
};

pub const BvhBuildNode = struct {
    bbox: BoundingBox,
    lhs: usize,
    rhs: usize,
    is_leafs_shapes: u1,
    shape_idx_start: usize,
    shape_idx_end: usize,
};

pub const ShapeBoundingBox = struct {
    bbox: BoundingBox,
    center: Vec3f32,
    shape_idx: usize,

    pub fn create(bbox: BoundingBox, shape_idx: usize) ShapeBoundingBox {
        return ShapeBoundingBox{
            .bbox = bbox,
            .center = utils_geo.get_bounding_box_center(bbox),
            .shape_idx = shape_idx,
        };
    }
};

pub fn init() ControllerObjectBVH {
    return .{
        .bvh_method = BvhMethod.EqualSize,
        .infinite_shape = std.ArrayList(usize).init(gpa),
        ._tmp_shape_bounding_box_slice = std.ArrayList(ShapeBoundingBox).init(gpa),
        ._tmp_bhv_tree = std.ArrayList(BvhBuildNode).init(gpa),
    };
}

pub fn clean_after_bhv_construction(self: *ControllerObjectBVH) void {
    self._tmp_shape_bounding_box_slice.clearAndFree();
    self._tmp_bhv_tree.clearAndFree();
}

pub fn deinit(self: *ControllerObjectBVH) void {
    self.infinite_shape.deinit();
    self._tmp_bhv_tree.deinit();
    self._tmp_shape_bounding_box_slice.deinit();
}

pub fn build_bvh(self: *ControllerObjectBVH, controller_object: *ControllerObject) !void {
    try self.populate_shape_bbox_and_infinite_shape_arr_list(controller_object);
    defer self.clean_after_bhv_construction();

    const axis = choose_axis_to_use_for_splitting(&self._tmp_shape_bounding_box_slice);
    sort_tmp_shape_bounding_box_on_axis(&self._tmp_shape_bounding_box_slice, axis);
    _ = try populate_bvh_build_node_equal_counts(
        &self._tmp_shape_bounding_box_slice,
        &self._tmp_bhv_tree,
        axis,
    );
}

fn populate_shape_bbox_and_infinite_shape_arr_list(
    self: *ControllerObjectBVH,
    controller_object: *ControllerObject,
) !void {
    for (0.., controller_object.array_shape.items) |i, shape| {
        switch (shape.?.data) {
            .ImplicitPlane => {
                try self.infinite_shape.append(i);
                continue;
            },
            inline else => {},
        }

        const position = controller_object.array_tmatrix.items[shape.?.handle_tmatrix.idx].?.get_position();
        const bounding_box = switch (shape.?.data) {
            .ImplicitSphere => |sphere| utils_geo.gen_bbox_implicit_sphere(position, sphere.radius),
            inline else => unreachable,
        };

        try self._tmp_shape_bounding_box_slice.append(
            ShapeBoundingBox.create(bounding_box, i),
        );
    }
}

fn choose_axis_to_use_for_splitting(bb_arr_list: *std.ArrayList(ShapeBoundingBox)) Axis {
    const bb_list = bb_arr_list.items;

    var x_min = bb_list[0].center.x;
    var x_max = bb_list[0].center.x;
    var y_min = bb_list[0].center.y;
    var y_max = bb_list[0].center.y;
    var z_min = bb_list[0].center.z;
    var z_max = bb_list[0].center.z;

    for (bb_list) |bb| {
        if (bb.center.x < x_min) x_min = bb.center.x;
        if (bb.center.x > x_max) x_max = bb.center.x;
        if (bb.center.y < y_min) y_min = bb.center.y;
        if (bb.center.y > y_max) y_max = bb.center.y;
        if (bb.center.z < z_min) z_min = bb.center.z;
        if (bb.center.z > z_max) z_max = bb.center.z;
    }

    const x_interval = x_max - x_min;
    const y_interval = y_max - y_min;
    const z_interval = z_max - z_min;

    var max_interval = @max(x_interval, y_interval);
    max_interval = @max(max_interval, z_interval);

    if (max_interval == x_interval) {
        return Axis.x;
    } else if (max_interval == y_interval) {
        return Axis.y;
    } else {
        return Axis.z;
    }
}

fn sort_tmp_shape_bounding_box_on_axis(bb_arr_list: *std.ArrayList(ShapeBoundingBox), axis: Axis) void {
    switch (axis) {
        .x => std.mem.sort(ShapeBoundingBox, bb_arr_list.items, {}, compare_by_value_x),
        .y => std.mem.sort(ShapeBoundingBox, bb_arr_list.items, {}, compare_by_value_y),
        .z => std.mem.sort(ShapeBoundingBox, bb_arr_list.items, {}, compare_by_value_z),
    }
}

fn compare_by_value_x(context: void, a: ShapeBoundingBox, b: ShapeBoundingBox) bool {
    _ = context;
    return a.center.x < b.center.x;
}

fn compare_by_value_y(context: void, a: ShapeBoundingBox, b: ShapeBoundingBox) bool {
    _ = context;
    return a.center.y < b.center.y;
}

fn compare_by_value_z(context: void, a: ShapeBoundingBox, b: ShapeBoundingBox) bool {
    _ = context;
    return a.center.z < b.center.z;
}

fn populate_bvh_build_node_equal_counts(
    bb_arr_list: *std.ArrayList(ShapeBoundingBox),
    tmp_bvh_tree: *std.ArrayList(BvhBuildNode),
    axis: Axis,
) !usize {
    _ = axis;
    return try create_bvh_build_node(
        bb_arr_list,
        tmp_bvh_tree,
        0,
        bb_arr_list.items.len - 1,
    );
}

fn create_bvh_build_node(
    bb_arr_list: *std.ArrayList(ShapeBoundingBox),
    tmp_bvh_tree: *std.ArrayList(BvhBuildNode),
    start: usize,
    end: usize,
) !usize {
    var lhs: usize = 0;
    var rhs: usize = 0;
    var is_leafs_shapes: u1 = 0;
    var bbox: BoundingBox = undefined;

    const extend = end - start;
    if (extend < 2) {
        is_leafs_shapes = 1;
        if (extend == 0) {
            const item = bb_arr_list.items[start];
            bbox = item.bbox;
            lhs = item.shape_idx;
            rhs = item.shape_idx;
        } else {
            const item_lhs = bb_arr_list.items[start];
            const item_rhs = bb_arr_list.items[start + 1];
            lhs = item_lhs.shape_idx;
            rhs = item_rhs.shape_idx;
            bbox = item_lhs.bbox.expand(item_rhs.bbox);
        }
    } else {
        is_leafs_shapes = 0;
        const mid = (end - start) / 2 + start;
        lhs = try create_bvh_build_node(bb_arr_list, tmp_bvh_tree, start, mid);
        rhs = try create_bvh_build_node(bb_arr_list, tmp_bvh_tree, mid + 1, end);
        bbox = tmp_bvh_tree.items[lhs].bbox.expand(tmp_bvh_tree.items[rhs].bbox);
    }

    const ret = tmp_bvh_tree.items.len;
    try tmp_bvh_tree.append(BvhBuildNode{
        .bbox = bbox,
        .shape_idx_start = start,
        .shape_idx_end = end,
        .is_leafs_shapes = is_leafs_shapes,
        .lhs = lhs,
        .rhs = rhs,
    });
    return ret;
}

fn flatten_bvh_tree(
    tmp_bvh_tree: *std.ArrayList(BvhBuildNode),
    bvh_tree: *std.ArrayList(BvhNode),
    build_node_idx: usize,
) !usize {
    const node_build = tmp_bvh_tree.items[build_node_idx];
    if (node_build.is_leafs_shapes) {
        try bvh_tree.append(
            BvhNode{
                .bbox = node_build.bbox,
                .next = .{ .idx_second_children = node_build.lhs },
            },
        );
        try bvh_tree.append(
            BvhNode{
                .bbox = node_build.bbox,
                .next = .{ .idx_second_children = node_build.rhs },
            },
        );
    } else {
        const i = bvh_tree.items.len;
        try bvh_tree.append(
            BvhNode{
                .bbox = node_build.bbox,
                .next = .{ .idx_second_children = undefined },
            },
        );
        var offset = try flatten_bvh_tree(tmp_bvh_tree, bvh_tree, node_build.lhs);
        offset += try flatten_bvh_tree(tmp_bvh_tree, bvh_tree, node_build.rhs);
        bvh_tree.items[i].next.idx_second_children = offset;
    }
    return bvh_tree.items.len - 1;
}

fn check_collision_bbox(bbox: BoundingBox, ray_origin: Vec3f32, ray_direction: Vec3f32) bool {
    _ = bbox;
    _ = ray_origin;
    _ = ray_direction;
}
fn traverse_bvh_tree(
    bvh_tree: *std.ArrayList(BvhNode),
    ray_origin: Vec3f32,
    ray_direction: Vec3f32,
) usize {
    var stack_node = [128]usize;
    var stack_idx: usize = 0;
    var bhv_tree_idx: usize = 0;
    var node: BvhNode = undefined;
    var move_direction: u1 = 0; // 0 is left, 1 is right.
    while (true) {
        node = bvh_tree.items[bhv_tree_idx];
        if (!check_collision_bbox(node.bbox, ray_origin, ray_direction)) {
            if (stack_idx == 0) return 0;
            move_direction = 1;
        } else {
            switch (node.next) {
                .idx_second_children => |val| {
                    stack_node[stack_idx] = val;
                    stack_idx += 1;
                    move_direction = 0;
                },
                .idx_shape => |val| {
                    suspend val;
                    move_direction = 1;
                },
            }
        }
        if (move_direction == 0) {
            bhv_tree_idx += 1;
        } else {
            if (stack_idx == 0) return 0;
            bhv_tree_idx = stack_node[stack_idx - 1];
            stack_idx -= 1;
        }
    }
}

test "integration_build_bvh" {
    var controller_object = ControllerObject.init();
    controller_object.deinit();

    _ = try controller_object.add_shape(
        "sphere_1",
        definitions.Shape{ .ImplicitSphere = .{ .radius = 5 } },
        maths_tmat.TMatrix.create_at_position(Vec3f32{ .x = 0, .y = 0, .z = 4 }),
        undefined,
    );
    _ = try controller_object.add_shape(
        "sphere_2",
        definitions.Shape{ .ImplicitSphere = .{ .radius = 5 } },
        maths_tmat.TMatrix.create_at_position(Vec3f32{ .x = 0, .y = 0, .z = 10 }),
        undefined,
    );
    _ = try controller_object.add_shape(
        "sphere_3",
        definitions.Shape{ .ImplicitSphere = .{ .radius = 5 } },
        maths_tmat.TMatrix.create_at_position(Vec3f32{ .x = 0, .y = 0, .z = -20 }),
        undefined,
    );
    _ = try controller_object.add_shape(
        "sphere_4",
        definitions.Shape{ .ImplicitSphere = .{ .radius = 5 } },
        maths_tmat.TMatrix.create_at_position(Vec3f32{ .x = 30, .y = 0, .z = -20 }),
        undefined,
    );

    var controller_object_bvh = ControllerObjectBVH.init();
    defer controller_object_bvh.deinit();

    try controller_object_bvh.build_bvh(&controller_object);
}

test "choose_axis_for_splitting" {
    var bbox_vec = std.ArrayList(ShapeBoundingBox).init(gpa);
    defer bbox_vec.deinit();

    try bbox_vec.append(
        ShapeBoundingBox.create(
            BoundingBox.create_square_box_at_position(
                Vec3f32{ .x = 6, .y = 0, .z = 0 },
                5,
            ),
            undefined,
        ),
    );

    try bbox_vec.append(
        ShapeBoundingBox.create(
            BoundingBox.create_square_box_at_position(
                Vec3f32{ .x = 2, .y = 0, .z = 7 },
                6,
            ),
            undefined,
        ),
    );

    try bbox_vec.append(
        ShapeBoundingBox.create(
            BoundingBox.create_square_box_at_position(
                Vec3f32{ .x = -8, .y = 14, .z = 50 },
                8,
            ),
            undefined,
        ),
    );

    const axis = choose_axis_to_use_for_splitting(&bbox_vec);
    try std.testing.expectEqual(Axis.z, axis);
}

test "sort_tmp_shape_bounding_box_on_axis" {
    var bbox_vec = std.ArrayList(ShapeBoundingBox).init(gpa);
    defer bbox_vec.deinit();

    try bbox_vec.append(
        ShapeBoundingBox.create(
            BoundingBox.create_square_box_at_position(
                Vec3f32{ .x = 6, .y = 0, .z = 0 },
                5,
            ),
            0,
        ),
    );

    try bbox_vec.append(
        ShapeBoundingBox.create(
            BoundingBox.create_square_box_at_position(
                Vec3f32{ .x = 2, .y = 1, .z = 7 },
                6,
            ),
            1,
        ),
    );

    try bbox_vec.append(
        ShapeBoundingBox.create(
            BoundingBox.create_square_box_at_position(
                Vec3f32{ .x = -8, .y = 14, .z = 50 },
                8,
            ),
            2,
        ),
    );

    sort_tmp_shape_bounding_box_on_axis(&bbox_vec, Axis.x);
    try std.testing.expectEqual(bbox_vec.items[0].shape_idx, 2);
    try std.testing.expectEqual(bbox_vec.items[1].shape_idx, 1);
    try std.testing.expectEqual(bbox_vec.items[2].shape_idx, 0);

    sort_tmp_shape_bounding_box_on_axis(&bbox_vec, Axis.y);
    try std.testing.expectEqual(bbox_vec.items[0].shape_idx, 0);
    try std.testing.expectEqual(bbox_vec.items[1].shape_idx, 1);
    try std.testing.expectEqual(bbox_vec.items[2].shape_idx, 2);

    sort_tmp_shape_bounding_box_on_axis(&bbox_vec, Axis.z);
    try std.testing.expectEqual(bbox_vec.items[0].shape_idx, 0);
    try std.testing.expectEqual(bbox_vec.items[1].shape_idx, 1);
    try std.testing.expectEqual(bbox_vec.items[2].shape_idx, 2);
}

test "equalCounts" {
    var bbox_vec = std.ArrayList(ShapeBoundingBox).init(gpa);
    defer bbox_vec.deinit();

    var build_node_vec = std.ArrayList(BvhBuildNode).init(gpa);
    defer build_node_vec.deinit();

    const shape_bounding_box_1 = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = -10, .y = 3, .z = 0 },
            5,
        ),
        100,
    );

    const shape_bounding_box_2 = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = 2, .y = 1, .z = 7 },
            6,
        ),
        101,
    );

    const shape_bounding_box_3 = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = 10, .y = 14, .z = 50 },
            8,
        ),
        102,
    );

    try bbox_vec.append(shape_bounding_box_1);
    try bbox_vec.append(shape_bounding_box_2);
    try bbox_vec.append(shape_bounding_box_3);

    const root_build_node_idx = try populate_bvh_build_node_equal_counts(
        &bbox_vec,
        &build_node_vec,
        Axis.x,
    );
    const root_build_node = build_node_vec.items[root_build_node_idx];
    const expected_bounding_box_root_node = shape_bounding_box_1.bbox
        .expand(shape_bounding_box_2.bbox)
        .expand(shape_bounding_box_3.bbox);
    try std.testing.expectEqual(expected_bounding_box_root_node, root_build_node.bbox);
    try std.testing.expectEqual(0, root_build_node.is_leafs_shapes);

    const first_children_node = build_node_vec.items[root_build_node.lhs];
    const expected_bounding_box_first_children_node = shape_bounding_box_1.bbox
        .expand(shape_bounding_box_2.bbox);
    try std.testing.expectEqual(expected_bounding_box_first_children_node, first_children_node.bbox);
    try std.testing.expectEqual(1, first_children_node.is_leafs_shapes);
    try std.testing.expectEqual(100, first_children_node.lhs);
    try std.testing.expectEqual(101, first_children_node.rhs);

    const second_children_node = build_node_vec.items[root_build_node.rhs];
    const expected_bounding_box_second_children_node = shape_bounding_box_3.bbox;
    try std.testing.expectEqual(expected_bounding_box_second_children_node, second_children_node.bbox);
    try std.testing.expectEqual(1, second_children_node.is_leafs_shapes);
    try std.testing.expectEqual(102, second_children_node.lhs);
    try std.testing.expectEqual(102, second_children_node.rhs);
}
