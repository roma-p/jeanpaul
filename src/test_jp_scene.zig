const std = @import("std");
const jp_scene = @import("jp_scene.zig");
const jp_object = @import("jp_object.zig");

const JpObject = jp_object.JpObject;
const ShapeTypeId = jp_object.ShapeTypeId;

test "scene_create_delete_add_obj" {
    var scene = try jp_scene.JpScene.new();
    defer scene.delete();

    var sphere_1 = try JpObject.new("sphere_1", ShapeTypeId.ImplicitSphere);
    defer sphere_1.delete();

    var light_1 = try JpObject.new("light_1", ShapeTypeId.LightOmni);
    defer light_1.delete();

    try scene.add_object(sphere_1);
    try scene.add_light(light_1);
}
