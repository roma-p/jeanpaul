const std = @import("std");
const types = @import("types.zig");
const jp_ray = @import("jp_ray.zig");
const jp_color = @import("jp_color.zig");
const jp_scene = @import("jp_scene.zig");
const jp_object = @import("jp_object.zig");
const jp_material = @import("jp_material.zig");

pub fn render_lambert(
    position: types.Vec3f32,
    normal: types.Vec3f32,
    material: *jp_material.JpMaterial,
    scene: *jp_scene.JpScene,
) !jp_color.JpColor {
    var light_color = jp_color.JpColor{ .r = 0, .g = 0, .b = 0 };
    var hit = try jp_ray.JpRayHit.new();
    defer hit.delete();
    for (scene.objects.items) |light| {
        defer hit.reset();
        if (light.object_category != jp_object.JpObjectCategory.Light) continue;

        const vector_to_light: types.Vec3f32 = light.tmatrix.get_position().substract_vector(
            &position,
        );

        const does_intersect = try jp_ray.shot_ray(
            position,
            hit,
            vector_to_light,
            scene,
        );

        if (does_intersect and hit.distance < 0) {
            continue;
        }

        _ = normal;
        light_color = light_color.sum_color(material.mat.Lambert.kd_color);

        // const vector_to_light_normalised = vector_to_light.normalize();
        // const attenuation_factor = vector_to_light_normalised.product_dot(&normal);
        //
        // TODO MULITPLY !!
        // var single_light_contribution = material.mat.Lambert.diffuse.sum_color(light.shape.LightOmni.color);
        // single_light_contribution = single_light_contribution.multiply(attenuation_factor);
        // light_color = light_color.sum_color(single_light_contribution);

    }
    return light_color;
}
