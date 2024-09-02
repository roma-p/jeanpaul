const std = @import("std");
const mem = std.mem;
const gpa = std.heap.page_allocator;

const ControllerObject = @import("controller_object.zig");

const definitions = @import("definitions.zig");

const data_handles = @import("data_handle.zig");
const data_render_settings = @import("data_render_settings.zig");

const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");
const maths_bbox = @import("maths_bbox.zig");
const maths_ray = @import("maths_ray.zig");

const Vec3f32 = maths_vec.Vec3f32;
const Axis = maths_vec.Axis;
const BoundingBox = maths_bbox.BoundingBox;
const Ray = maths_ray.Ray;
const CollisionAccelerationMethod = data_render_settings.CollisionAccelerationMethod;
const HandleShape = data_handles.HandleShape;

const utils_geo = @import("utils_geo.zig");

controller_object: *ControllerObject,
bvh_method: CollisionAccelerationMethod,
max_shape_per_node: usize, // max number of shape a leaf node of bvh tree can hold.

bvh_out_array: []usize, // result of bvh tree traversal: holds all idx of shape that ray may hit.

_bvh_tree: std.ArrayList(BvhNode),
_shape_idx_ordered: []usize, // holds idx of every shape ordered against a given axis.
_shape_bb_array: []ShapeBoundingBox, // holds bouding box of every shape.
_shape_bb_array_len: usize, // real len of previous array.
_bhv_tree_build: std.ArrayList(BvhBuildNode), // tmp tree that gets eventually flatten to _bvh_tree for speed traversal.
_infinite_shape_number: usize, // count of shape that will not be in bvh tree because of inifinite size boudning box.

const ControllerBVH = @This();

pub const BvhNode = struct {
    bbox: BoundingBox,
    shape_numbers: usize, // = 0 -> not leaf node.
    idx: usize, // if leaf node: holds _shape_idx_ordered start idx, otherwise rhs idx.
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

pub fn init(
    collision_acceleration_method: CollisionAccelerationMethod,
    controller_object: *ControllerObject,
) !ControllerBVH {
    switch (collision_acceleration_method) {
        .BvhEqualSize => {},
        .BvhSAH => unreachable,
        inline else => unreachable,
    }
    const shape_number = controller_object.array_shape.items.len;
    return .{
        .controller_object = controller_object,
        .bvh_method = collision_acceleration_method,
        .max_shape_per_node = 4, // If 1: do weird artfefact.
        .bvh_out_array = try gpa.alloc(usize, shape_number),
        ._bvh_tree = std.ArrayList(BvhNode).init(gpa),
        ._bhv_tree_build = std.ArrayList(BvhBuildNode).init(gpa),
        ._shape_idx_ordered = try gpa.alloc(usize, shape_number),
        ._shape_bb_array = try gpa.alloc(ShapeBoundingBox, shape_number),
        ._shape_bb_array_len = 0,
        ._infinite_shape_number = 0,
    };
}

pub fn clean_after_bhv_construction(self: *ControllerBVH) void {
    self._bhv_tree_build.clearAndFree();
}

pub fn deinit(self: *ControllerBVH) void {
    self._bvh_tree.deinit();
    self._bhv_tree_build.deinit();
    gpa.free(self.bvh_out_array);
    gpa.free(self._shape_idx_ordered);
    gpa.free(self._shape_bb_array);
}

pub fn build_bvh(self: *ControllerBVH) !void {
    self._shape_bb_array_len = try self.populate_shape_bbox_and_infinite_shape_arr_list(self.controller_object);
    defer self.clean_after_bhv_construction();

    const axis = choose_axis_to_use_for_splitting(
        &self._shape_bb_array,
        self._shape_bb_array_len,
    );

    sort_tmp_shape_bounding_box_on_axis(
        &self._shape_bb_array,
        self._shape_bb_array_len,
        axis,
    );

    try populate_shape_idx_ordered(
        &self._shape_bb_array,
        &self._shape_idx_ordered,
        self._shape_bb_array_len,
    );

    const root_build_node_idx = try populate_bvh_build_node_equal_counts(
        &self._shape_bb_array,
        &self._bhv_tree_build,
        axis,
        self.max_shape_per_node,
        self._shape_bb_array_len,
    );
    _ = try flatten_bvh_tree(
        &self._bhv_tree_build,
        &self._bvh_tree,
        root_build_node_idx,
    );
}

fn populate_shape_bbox_and_infinite_shape_arr_list(
    self: *ControllerBVH,
    controller_object: *ControllerObject,
) !usize {
    var j: usize = 0;
    for (0.., controller_object.array_shape.items) |i, shape| {
        switch (shape.?.data) {
            .ImplicitPlane => {
                self.bvh_out_array[self._infinite_shape_number] = i;
                self._infinite_shape_number += 1;
                continue;
            },
            inline else => {},
        }

        const position = controller_object.array_tmatrix.items[shape.?.handle_tmatrix.idx].?.get_position();
        const bounding_box = switch (shape.?.data) {
            .ImplicitSphere => |sphere| utils_geo.gen_bbox_implicit_sphere(position, sphere.radius),
            inline else => unreachable,
        };

        self._shape_bb_array[j] = ShapeBoundingBox.create(bounding_box, i);

        j += 1;
    }
    return j;
}

fn choose_axis_to_use_for_splitting(bb_list: *[]ShapeBoundingBox, list_len: usize) Axis {
    var x_min = bb_list.*[0].center.x;
    var x_max = bb_list.*[0].center.x;
    var y_min = bb_list.*[0].center.y;
    var y_max = bb_list.*[0].center.y;
    var z_min = bb_list.*[0].center.z;
    var z_max = bb_list.*[0].center.z;

    var i: usize = 0;
    while (i < list_len) : (i += 1) {
        const item = bb_list.*[i];
        if (item.center.x < x_min) x_min = item.center.x;
        if (item.center.x > x_max) x_max = item.center.x;
        if (item.center.y < y_min) y_min = item.center.y;
        if (item.center.y > y_max) y_max = item.center.y;
        if (item.center.z < z_min) z_min = item.center.z;
        if (item.center.z > z_max) z_max = item.center.z;
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

fn sort_tmp_shape_bounding_box_on_axis(
    bb_list: *[]ShapeBoundingBox,
    bb_list_len: usize,
    axis: Axis,
) void {
    switch (axis) {
        .x => std.mem.sort(ShapeBoundingBox, bb_list.*[0..bb_list_len], {}, compare_by_value_x),
        .y => std.mem.sort(ShapeBoundingBox, bb_list.*[0..bb_list_len], {}, compare_by_value_y),
        .z => std.mem.sort(ShapeBoundingBox, bb_list.*[0..bb_list_len], {}, compare_by_value_z),
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

fn populate_shape_idx_ordered(
    bb_list: *[]ShapeBoundingBox,
    shape_idx_ordered: *[]usize,
    list_len: usize,
) !void {
    var i: usize = 0;
    while (i < list_len) : (i += 1) {
        shape_idx_ordered.*[i] = bb_list.*[i].shape_idx;
    }
}

fn populate_bvh_build_node_equal_counts(
    bb_list: *[]ShapeBoundingBox,
    tmp_bvh_tree: *std.ArrayList(BvhBuildNode),
    axis: Axis,
    max_shape_per_node: usize,
    bb_list_len: usize,
) !usize {
    _ = axis;
    return try create_bvh_build_node(
        bb_list,
        tmp_bvh_tree,
        0,
        bb_list_len - 1, // TODO : what happen if bb_list_len = 0 ??
        max_shape_per_node,
    );
}

fn create_bvh_build_node(
    bb_list: *[]ShapeBoundingBox,
    tmp_bvh_tree: *std.ArrayList(BvhBuildNode),
    start: usize,
    end: usize,
    max_shape_per_node: usize,
) !usize {
    var lhs: usize = 0;
    var rhs: usize = 0;
    var is_leafs_shapes: u1 = 0;
    var bbox: BoundingBox = undefined;

    const extend = end - start;

    if (extend <= max_shape_per_node) {
        is_leafs_shapes = 1;

        bbox = bb_list.*[start].bbox;
        var i: usize = 1;
        while (i <= extend) : (i += 1) {
            bbox = bbox.expand(bb_list.*[start + i].bbox);
        }
    } else {
        is_leafs_shapes = 0;
        const mid = (end - start) / 2 + start;
        lhs = try create_bvh_build_node(bb_list, tmp_bvh_tree, start, mid, max_shape_per_node);
        rhs = try create_bvh_build_node(bb_list, tmp_bvh_tree, mid + 1, end, max_shape_per_node);
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
    root_build_node_idx: usize,
) !usize {
    const node_build = tmp_bvh_tree.items[root_build_node_idx];
    if (node_build.is_leafs_shapes == 1) {
        try bvh_tree.append(
            BvhNode{
                .bbox = node_build.bbox,
                .shape_numbers = node_build.shape_idx_end - node_build.shape_idx_start,
                .idx = node_build.shape_idx_start,
            },
        );
    } else {
        const i = bvh_tree.items.len;
        try bvh_tree.append(
            BvhNode{
                .bbox = node_build.bbox,
                .shape_numbers = 0,
                .idx = undefined,
            },
        );
        const offset = try flatten_bvh_tree(tmp_bvh_tree, bvh_tree, node_build.lhs);
        _ = try flatten_bvh_tree(tmp_bvh_tree, bvh_tree, node_build.rhs);
        bvh_tree.items[i].idx = offset;
    }
    return bvh_tree.items.len;
}

pub fn traverse_bvh_tree(self: *ControllerBVH, ray: Ray) usize {
    return _traverse_bvh_tree(
        &self._bvh_tree,
        &self._shape_idx_ordered,
        &self.bvh_out_array,
        self._infinite_shape_number,
        ray,
    );
}

fn _traverse_bvh_tree(
    bvh_tree: *std.ArrayList(BvhNode),
    shape_idx_ordered: *[]usize,
    bvh_out_array: *[]usize,
    bvh_out_idx_offset: usize,
    ray: Ray,
) usize {
    if (bvh_tree.items.len == 0) {
        return bvh_out_idx_offset;
    }

    if (bvh_tree.items.len == 1) {
        var i: usize = 0;
        const node = bvh_tree.items[0];
        while (i <= node.shape_numbers) : (i += 1) {
            bvh_out_array.*[bvh_out_idx_offset + i] = shape_idx_ordered.*[i];
        }
        return bvh_out_idx_offset + node.shape_numbers + 1;
    }

    var bvh_out_len = bvh_out_idx_offset;
    var stack_node = [_]usize{0} ** 1024; // max depth, so 1024 * 1024 max items. TODO: allocate with obj would be better...
    var stack_idx: usize = 0; // idx of last valid value on stack_node.
    var bhv_tree_idx: usize = 0;
    var node: BvhNode = bvh_tree.items[0];
    stack_node[0] = node.idx;
    var move_direction: u1 = 0; // 0 is left, 1 is right.
    while (true) {
        if (!utils_geo.check_ray_hit_aabb(ray, node.bbox)) {
            if (stack_idx == 0) break;
            move_direction = 1;
        } else {
            if (node.shape_numbers == 0) {
                move_direction = 0;
                stack_node[stack_idx] = node.idx;
                stack_idx += 1;
            } else {
                var i = node.idx;
                while (i <= node.idx + node.shape_numbers) : (i += 1) {
                    bvh_out_array.*[bvh_out_len] = shape_idx_ordered.*[i];
                    bvh_out_len += 1;
                }
                move_direction = 1;
            }
        }
        if (move_direction == 0) {
            bhv_tree_idx += 1;
        } else {
            if (stack_idx == 0) break;
            bhv_tree_idx = stack_node[stack_idx - 1];
            stack_idx -= 1;
        }
        node = bvh_tree.items[bhv_tree_idx];
    }
    return bvh_out_len;
}

test "choose_axis_for_splitting" {
    var bbox_arr = try gpa.alloc(ShapeBoundingBox, 3);
    defer gpa.free(bbox_arr);

    bbox_arr[0] = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = 6, .y = 0, .z = 0 },
            5,
        ),
        undefined,
    );

    bbox_arr[1] = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = 2, .y = 0, .z = 7 },
            6,
        ),
        undefined,
    );

    bbox_arr[2] = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = -8, .y = 14, .z = 50 },
            8,
        ),
        undefined,
    );

    const axis = choose_axis_to_use_for_splitting(&bbox_arr, 3);
    try std.testing.expectEqual(Axis.z, axis);
}

test "sort_tmp_shape_bounding_box_on_axis" {
    var bbox_arr = try gpa.alloc(ShapeBoundingBox, 3);
    defer gpa.free(bbox_arr);

    bbox_arr[0] = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = 6, .y = 0, .z = 0 },
            5,
        ),
        0,
    );

    bbox_arr[1] = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = 2, .y = 1, .z = 7 },
            6,
        ),
        1,
    );

    bbox_arr[2] = ShapeBoundingBox.create(
        BoundingBox.create_square_box_at_position(
            Vec3f32{ .x = -8, .y = 14, .z = 50 },
            8,
        ),
        2,
    );

    sort_tmp_shape_bounding_box_on_axis(&bbox_arr, 3, Axis.x);
    try std.testing.expectEqual(2, bbox_arr[0].shape_idx);
    try std.testing.expectEqual(1, bbox_arr[1].shape_idx);
    try std.testing.expectEqual(0, bbox_arr[2].shape_idx);

    sort_tmp_shape_bounding_box_on_axis(&bbox_arr, 3, Axis.y);
    try std.testing.expectEqual(0, bbox_arr[0].shape_idx);
    try std.testing.expectEqual(1, bbox_arr[1].shape_idx);
    try std.testing.expectEqual(2, bbox_arr[2].shape_idx);

    sort_tmp_shape_bounding_box_on_axis(&bbox_arr, 3, Axis.z);
    try std.testing.expectEqual(0, bbox_arr[0].shape_idx);
    try std.testing.expectEqual(1, bbox_arr[1].shape_idx);
    try std.testing.expectEqual(2, bbox_arr[2].shape_idx);
}

test "equalCounts" {
    var bbox_arr = try gpa.alloc(ShapeBoundingBox, 3);
    defer gpa.free(bbox_arr);

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

    bbox_arr[0] = shape_bounding_box_1;
    bbox_arr[1] = shape_bounding_box_2;
    bbox_arr[2] = shape_bounding_box_3;

    const root_build_node_idx = try populate_bvh_build_node_equal_counts(
        &bbox_arr,
        &build_node_vec,
        Axis.x,
        1,
        3,
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
    try std.testing.expectEqual(0, first_children_node.shape_idx_start);
    try std.testing.expectEqual(1, first_children_node.shape_idx_end);
    // => TODO: check idx in sorted shapes idx.

    const second_children_node = build_node_vec.items[root_build_node.rhs];
    const expected_bounding_box_second_children_node = shape_bounding_box_3.bbox;
    try std.testing.expectEqual(expected_bounding_box_second_children_node, second_children_node.bbox);
    try std.testing.expectEqual(1, second_children_node.is_leafs_shapes);
    try std.testing.expectEqual(0, second_children_node.lhs);
    try std.testing.expectEqual(0, second_children_node.rhs);
    // -> Same
}

test "flattenBvhTree" {
    var build_node_vec = std.ArrayList(BvhBuildNode).init(gpa);
    defer build_node_vec.deinit();

    var node_vec = std.ArrayList(BvhNode).init(gpa);
    defer node_vec.deinit();

    // A
    try build_node_vec.append(
        BvhBuildNode{
            .bbox = BoundingBox.create_null(),
            .lhs = 0,
            .rhs = 0,
            .is_leafs_shapes = 1,
            .shape_idx_start = 0,
            .shape_idx_end = 4,
        },
    );

    // B
    try build_node_vec.append(
        BvhBuildNode{
            .bbox = BoundingBox.create_null(),
            .lhs = 0,
            .rhs = 0,
            .is_leafs_shapes = 1,
            .shape_idx_start = 4,
            .shape_idx_end = 5,
        },
    );

    // C
    try build_node_vec.append(
        BvhBuildNode{
            .bbox = BoundingBox.create_null(),
            .lhs = 0,
            .rhs = 1,
            .is_leafs_shapes = 0,
            .shape_idx_start = 0,
            .shape_idx_end = 4,
        },
    );

    // D
    try build_node_vec.append(
        BvhBuildNode{
            .bbox = BoundingBox.create_null(),
            .lhs = 0,
            .rhs = 0,
            .is_leafs_shapes = 1,
            .shape_idx_start = 5,
            .shape_idx_end = 6,
        },
    );

    // E
    try build_node_vec.append(
        BvhBuildNode{
            .bbox = BoundingBox.create_null(),
            .lhs = 2,
            .rhs = 3,
            .is_leafs_shapes = 0,
            .shape_idx_start = 0,
            .shape_idx_end = 5,
        },
    );

    //     E
    //    /\
    //   C  D
    //  /\
    // A  B
    //
    // idx -> E:4, D: 3, C: 2, B: 1, A: 0
    // expected shapes per node -> A:3, B:1: D:1

    _ = try flatten_bvh_tree(&build_node_vec, &node_vec, 4);

    const E = node_vec.items[0];
    try std.testing.expectEqual(0, E.shape_numbers);
    try std.testing.expectEqual(4, E.idx);

    const C = node_vec.items[1];
    try std.testing.expectEqual(0, C.shape_numbers);
    try std.testing.expectEqual(3, C.idx);

    const A = node_vec.items[2];
    try std.testing.expectEqual(4, A.shape_numbers);
    try std.testing.expectEqual(0, A.idx);

    const B = node_vec.items[3];
    try std.testing.expectEqual(1, B.shape_numbers);
    try std.testing.expectEqual(4, B.idx);

    const D = node_vec.items[4];
    try std.testing.expectEqual(1, D.shape_numbers);
    try std.testing.expectEqual(5, D.idx);
}

test "integration_build_bvh" {
    var controller_object = ControllerObject.init();
    controller_object.deinit();

    _ = try controller_object.add_shape(
        "sphere_1",
        definitions.Shape{ .ImplicitSphere = .{ .radius = 5 } },
        maths_tmat.TMatrix.create_at_position(Vec3f32{ .x = 0, .y = 0, .z = 1 }),
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
    _ = try controller_object.add_shape(
        "sphere_5",
        definitions.Shape{ .ImplicitSphere = .{ .radius = 1 } },
        maths_tmat.TMatrix.create_at_position(Vec3f32{ .x = -100, .y = 0, .z = -300 }),
        undefined,
    );

    var controller_bvh = try ControllerBVH.init(
        CollisionAccelerationMethod.BvhEqualSize,
        &controller_object,
    );
    controller_bvh.max_shape_per_node = 2;
    defer controller_bvh.deinit();

    try controller_bvh.build_bvh();

    const ray = Ray{
        .o = Vec3f32{ .x = 1, .y = 1, .z = -100 },
        .d = Vec3f32{ .x = 0, .y = 0, .z = 1 },
    };
    const i = controller_bvh.traverse_bvh_tree(ray);
    try std.testing.expectEqual(5, i);
}
