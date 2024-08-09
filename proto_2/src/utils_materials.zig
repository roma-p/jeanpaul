const std = @import("std");

const definitions = @import("definitions.zig");
const data_color = @import("data_color.zig");
const utils_geo = @import("utils_geo.zig");
const maths_vec = @import("maths_vec.zig");

const Color = data_color.Color;
const Vecf32 = maths_vec.Vec3f32;
const RndGen = std.rand.DefaultPrng;

pub const ScatterResult = struct {
    is_scatterred: u1 = 0,
    ray_origin: Vecf32 = Vecf32.create_origin(),
    ray_direction: Vecf32 = Vecf32.create_origin(),
    attenuation: Color = data_color.COLOR_EMPTY,
};

pub fn scatter_lambertian(
    p: Vecf32,
    normal: Vecf32,
    base_color: Color,
    intensity: f32,
    ambiant: f32,
    rng: *RndGen,
) !ScatterResult {
    const direction = utils_geo.gen_vec_random_spheric_normalized(rng).sum_vector(normal);
    // const direction = utils_geo.gen_vec_random_hemisphere_normalized(normal, rng);
    const tmp = base_color.product(intensity); //sum_with_float(ambiant * -1);
    const att = tmp.sum_with_float(ambiant * -1);
    return ScatterResult{
        .is_scatterred = 1,
        .ray_origin = p,
        .ray_direction = direction,
        .attenuation = att,
    };
}

pub fn get_emitted_color(
    color: Color,
    intensity: f32,
    exposition: f32,
    decay_mode: definitions.LightDecayMode,
    ray_length: f32,
) Color {
    const full_intensity = intensity * std.math.pow(f32, 2, exposition);
    const with_decay = switch (decay_mode) {
        .NoDecay => full_intensity,
        .Quadratic => full_intensity / (ray_length * ray_length),
    };
    return color.product(with_decay);
}
