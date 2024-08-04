const std = @import("std");
const data_handles = @import("data_handle.zig");
const definitions = @import("definitions.zig");
const data_render_settings = @import("data_render_settings.zig");
const maths_vec = @import("maths_vec.zig");
const maths_tmat = @import("maths_tmat.zig");
const utils_tile_rendering = @import("utils_tile_rendering.zig");
const utils_camera = @import("utils_camera.zig");
const ControllereScene = @import("controller_scene.zig");
const ControllereObject = @import("controller_object.zig");

pub const RenderInfo = struct {
    pixel_size: f32,

    image_width: u16,
    image_height: u16,

    samples: u16,
    bounces: u16,

    render_type: data_render_settings.RenderType,
    focal_plane_center: maths_vec.Vec3f32,
    data_per_render_type: DataPerRenderType,

    samples_nbr: u16,
    samples_invert: f32,

    pub const DataPerRenderType = union(data_render_settings.RenderType) {
        SingleThread: struct {},
        Scanline: struct {},
        Tile: struct {
            tile_size: u16,
            tile_number: u16,
            tile_x_number: u16,
            tile_y_number: u16,
        },
    };

    pub fn create_from_scene(controller_scene: *ControllereScene, camera_handle: data_handles.HandleCamera) !RenderInfo {
        var controller_object = controller_scene.controller_object;
        const scene_render_settings = controller_scene.render_settings;

        const image_width: u16 = scene_render_settings.width;
        const image_height: u16 = scene_render_settings.height;

        const ptr_cam_entity: *const ControllereObject.CameraEntity = try controller_object.get_camera_pointer(camera_handle);
        const ptr_cam_tmatrix: *const maths_tmat.TMatrix = try controller_object.get_tmatrix_pointer(
            ptr_cam_entity.*.handle_tmatrix,
        );

        switch (ptr_cam_entity.data) {
            definitions.Camera.Perspective => {},
            inline else => unreachable,
        }

        const focal_length: f32 = ptr_cam_entity.*.data.Perspective.focal_length;
        const field_of_view: f32 = ptr_cam_entity.*.data.Perspective.field_of_view;

        const tile_x_y: maths_vec.Vec2(u16) = utils_tile_rendering.calculate_tile_number(
            image_width,
            image_height,
            scene_render_settings.tile_size,
        );

        const cam_direction: maths_vec.Vec3f32 = utils_camera.get_camera_absolute_direction(
            ptr_cam_tmatrix.*,
            ControllereObject.CameraEntity.CAMERA_DIRECTION,
        );

        const cam_focal_plane_center: maths_vec.Vec3f32 = utils_camera.get_camera_focal_plane_center(
            ptr_cam_tmatrix.*,
            cam_direction,
            focal_length,
        );

        const pixel_size: f32 = utils_camera.get_pixel_size_on_focal_plane(
            focal_length,
            field_of_view,
            image_width,
        );

        const sample_nbr = std.math.pow(u16, 2, scene_render_settings.samples);
        const sample_nbr_as_f32: f32 = @floatFromInt(sample_nbr);
        const invert_sample_nbr: f32 = 1 / sample_nbr_as_f32;

        return .{
            .pixel_size = pixel_size,
            .image_width = image_width,
            .image_height = image_height,
            .render_type = scene_render_settings.render_type,
            .samples = scene_render_settings.samples,
            .samples_nbr = sample_nbr,
            .samples_invert = invert_sample_nbr,
            .bounces = scene_render_settings.bounces,
            .focal_plane_center = cam_focal_plane_center,
            .data_per_render_type = switch (scene_render_settings.render_type) {
                data_render_settings.RenderType.Tile => RenderInfo.DataPerRenderType{
                    .Tile = .{
                        .tile_size = scene_render_settings.tile_size,
                        .tile_number = tile_x_y.x * tile_x_y.y,
                        .tile_x_number = tile_x_y.x,
                        .tile_y_number = tile_x_y.y,
                    },
                },
                data_render_settings.RenderType.Scanline => unreachable,
                data_render_settings.RenderType.SingleThread => unreachable,
            },
        };
    }
};
