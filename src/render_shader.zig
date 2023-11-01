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
    for (scene.objects.items) |light| {
        if (light.get_category() != jp_object.JpObjectCategory.Light) continue;

        var diffuse_color = material.mat.Lambert.kd_color;
        diffuse_color = diffuse_color.multiply_with_other_color(&light.shape.LightOmni.color);

        // computing ambiant pass.
        var pass_ambiant = diffuse_color.multiply(light.shape.LightOmni.intensity);
        pass_ambiant = diffuse_color.multiply(material.mat.Lambert.kd_ambiant);
        light_color = light_color.sum_color(pass_ambiant);

        // reaching light.
        const light_pos = light.tmatrix.get_position();
        const is_reachable = try jp_ray.is_point_reachable_by_ray(
            position,
            light_pos,
            scene,
        );
        if (!is_reachable) continue;

        // computing diffuse pass.

        const vector_to_light = light.tmatrix.get_position().substract_vector(&position);

        var light_i_on_position: f32 = undefined;
        switch (light.shape.LightOmni.decay_rate) {
            .NoDecay => light_i_on_position = light.shape.LightOmni.compute_intensity(),
            else => {
                const distance = vector_to_light.compute_length();
                light_i_on_position = light.shape.LightOmni.compute_intensity_from_distance(distance);
            },
        }

        // FIXME: decay rate -> p
        // qadratic not working...
        // use complete intensity as ambiant.

        const vector_to_light_normalised = vector_to_light.normalize();
        const attenuation_factor = vector_to_light_normalised.product_dot(&normal);

        var pass_diffuse = diffuse_color.multiply(material.mat.Lambert.kd_intensity);
        pass_diffuse = pass_diffuse.multiply(light_i_on_position);
        pass_diffuse = pass_diffuse.multiply(attenuation_factor);

        light_color = light_color.sum_color(pass_diffuse);
    }
    return light_color;
}

pub fn render_aov_alpha(material: *jp_material.JpMaterial) !jp_color.JpColor {
    return material.mat.AovAlpha.color;
}

pub fn render_aov_normal(normal: types.Vec3f32) !jp_color.JpColor {
    return jp_color.JpColor{
        .r = (normal.x + 1) / 2,
        .g = (normal.y + 1) / 2,
        .b = (normal.z + 1) / 2,
    };
}
