const std = @import("std");

const definitions = @import("definitions.zig");
const data_color = @import("data_color.zig");
const data_handle = @import("data_handle.zig");
const utils_geo = @import("utils_geo.zig");
const maths_vec = @import("maths_vec.zig");
const maths_ray = @import("maths_ray.zig");

const Color = data_color.Color;
const Vecf32 = maths_vec.Vec3f32;
const RndGen = std.rand.DefaultPrng;
const Ray = maths_ray.Ray;
const HandleMaterial = data_handle.HandleMaterial;

pub const ScatterResult = struct {
    is_scatterred: u1 = 0,
    ray_diffuse: ?Ray = null,
    ray_specular: ?Ray = null,
    ray_transmission: ?Ray = null,
    attenuation: Color = data_color.COLOR_EMPTY,
    emission: ?Color = null,
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
        .ray_diffuse = .{
            .o = p,
            .d = direction,
        },
        .attenuation = att,
        .emission = null,
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
    var direction = reflect(ray_direction, normal);
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
        .ray_specular = .{
            .o = p,
            .d = direction,
        },
        .attenuation = att,
        .emission = null,
    };
}

pub fn scatter_dieletric(
    p: Vecf32,
    ray_direction: Vecf32,
    normal: Vecf32,
    base_color: Color,
    ior_fraction: f32,
    rng: *RndGen,
) ScatterResult {
    const cos_theta = @min(1.0, ray_direction.product(-1).product_dot(normal));
    const sin_theta = @min(1.0, std.math.sqrt(1.0 - cos_theta * cos_theta));

    const cannot_refract = (ior_fraction * sin_theta > 1.0);

    if (cannot_refract or schlick_reflectance_idx(cos_theta, ior_fraction) > rng.random().float(f32)) {
        return ScatterResult{
            .is_scatterred = 1,
            .ray_transmission = .{
                .o = p,
                .d = reflect(ray_direction, normal),
            },
            .attenuation = base_color,
        };
    } else {
        return ScatterResult{
            .is_scatterred = 1,
            .ray_transmission = .{
                .o = p,
                .d = refract(ray_direction, normal, ior_fraction),
            },
            .attenuation = base_color,
        };
    }
}

pub fn get_emitted_color(
    color: Color,
    intensity: f32,
    exposition: f32,
    decay_mode: definitions.LightDecayMode,
    ray_length: f32,
) ScatterResult {
    const full_intensity = intensity * std.math.pow(f32, 2, exposition);
    const with_decay = switch (decay_mode) {
        .NoDecay => full_intensity,
        .Quadratic => full_intensity / (ray_length * ray_length),
    };
    return ScatterResult{
        .is_scatterred = 0,
        .emission = color.product(with_decay),
    };
}

pub fn reflect(ray_direction: Vecf32, normal: Vecf32) Vecf32 {
    const a = 2 * ray_direction.product_dot(normal);
    return ray_direction.substract_vector(normal.product(a)).normalize();
}

pub fn refract(ray_direction: Vecf32, normal: Vecf32, ior_fraction: f32) Vecf32 {
    const cos_theta = @min(1.0, ray_direction.product(-1).product_dot(normal));
    const r_dir_perp = ray_direction.sum_vector(normal.product(cos_theta)).product(ior_fraction);
    const r_dir_prll = normal.product(-1 * std.math.sqrt(@abs(1 - r_dir_perp.compute_length_squared())));
    return r_dir_perp.sum_vector(r_dir_prll).normalize();
}

pub fn schlick_reflectance_idx(cos_theta: f32, ior_fraction: f32) f32 {
    const r0 = (1 - ior_fraction) / (1 + ior_fraction);
    const r02 = r0 * r0;
    return r02 + (1 - r02) * std.math.pow(f32, 1 - cos_theta, 5);
}
