const std = @import("std");

const definitions = @import("definitions.zig");
const data_color = @import("data_color.zig");
const utils_geo = @import("utils_geo.zig");
const maths_vec = @import("maths_vec.zig");
const maths_ray = @import("maths_ray.zig");

const Color = data_color.Color;
const Vecf32 = maths_vec.Vec3f32;
const RndGen = std.rand.DefaultPrng;
const Ray = maths_ray.Ray;

pub const ScatterResult = struct {
    is_scatterred: u1 = 0,
    ray: Ray = Ray.create_null(),
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
    var direction = utils_geo.gen_vec_random_spheric_normalized(rng).sum_vector(normal);
    if (direction.almsot_null()) {
        direction = normal;
    }
    const tmp = base_color.product(intensity); //sum_with_float(ambiant * -1);
    const att = tmp.sum_with_float(ambiant * -1);
    return ScatterResult{
        .is_scatterred = 1,
        .ray = .{
            .o = p,
            .d = direction,
        },
        .attenuation = att,
    };
}

pub fn scatter_metal(
    p: Vecf32,
    ray_direction: Vecf32,
    normal: Vecf32,
    base_color: Color,
    intensity: f32,
    ambiant: f32,
    fuzz: f32,
    rng: *RndGen,
) !ScatterResult {
    const a = 2 * ray_direction.product_dot(normal);
    var direction = ray_direction.substract_vector(normal.product(a)).normalize();
    const fuzz_alteration = utils_geo.gen_vec_random_spheric_normalized(rng).product(fuzz);
    direction = direction.sum_vector(fuzz_alteration);

    const tmp = base_color.product(intensity); //sum_with_float(ambiant * -1);
    const att = tmp.sum_with_float(ambiant * -1);

    var is_scattered: u1 = undefined;
    if (direction.product_dot(normal) < 0) {
        is_scattered = 1;
    } else {
        is_scattered = 0;
    }

    return ScatterResult{
        .is_scatterred = is_scattered,
        .ray = .{
            .o = p,
            .d = direction,
        },
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
