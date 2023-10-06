const std = @import("std");
const jp_scene = @import("jp_scene.zig");
const jp_object = @import("jp_object.zig");

test "scene_create_delete_add_obj" {
    var scene = try jp_scene.create_scene();
    var sphere = try jp_object.create_sphere();
    try scene.add_object(sphere);
    jp_scene.destroy_scene(scene);
}
