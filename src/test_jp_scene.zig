const std = @import("std");
const jp_scene = @import("jp_scene.zig");
const jp_object = @import("jp_object.zig");

test "scene_create_delete_add_obj" {
    var scene = try jp_scene.JpScene.new();
    var sphere = try jp_object.create_sphere("sphere_1");
    var light = try jp_object.create_light_omni("light_1");
    try scene.add_object(sphere);
    try scene.add_light(light);
    scene.delete();
}
