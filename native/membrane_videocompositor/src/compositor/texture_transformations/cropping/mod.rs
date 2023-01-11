use bytemuck::{Pod, Zeroable};
use cgmath::*;

use crate::compositor::{math::Vec2d, VideoPlacement, VideoProperties};

use super::TextureTransformation;

/// Struct representing parameters for video cropping texture transformation.
/// top_left_corner represents the coords of the top left corner of cropped (visible)
/// part of the video (in x ∈ [0,1], y ∈ [0, 1] proportion range).
/// crop_width represents the width of the cropped video (visible part) in [0, 1] relative range.
/// crop_height represents the height of the cropped video (visible part) in [0, 1] relative range.
#[derive(Debug, Clone, Copy, Zeroable, Pod, PartialEq)]
#[repr(C)]
pub struct Cropping {
    crop_matrix: [[f32; 4]; 4],
    top_left_corner_crop_x: f32,
    top_left_corner_crop_y: f32,
    crop_width: f32,
    crop_height: f32,
    transform_position: u32,
    _padding: [u32; 3],
}

impl Cropping {
    pub fn new(
        top_left_corner: Vec2d<f32>,
        crop_size: Vec2d<f32>,
        transform_position: bool,
    ) -> Self {
        let scale_matrix = cgmath::Matrix4::from_nonuniform_scale(crop_size.x, crop_size.y, 1.0);
        let translation_matrix = cgmath::Matrix4::from_translation(Vector3 {
            x: top_left_corner.x,
            y: top_left_corner.y,
            z: 0.0,
        });

        Cropping {
            crop_matrix: (translation_matrix * scale_matrix).into(),
            top_left_corner_crop_x: top_left_corner.x,
            top_left_corner_crop_y: top_left_corner.y,
            crop_width: crop_size.x,
            crop_height: crop_size.y,
            transform_position: transform_position as u32,
            _padding: [0; 3],
        }
    }
}

impl TextureTransformation for Cropping {
    fn update_video_properties(&mut self, _properties: VideoProperties) {}

    fn transform_video_properties(&self, properties: VideoProperties) -> VideoProperties {
        let transformed_position = match self.transform_position != 0 {
            true => Vec2d {
                x: properties.placement.position.x
                    + (self.top_left_corner_crop_x * properties.placement.size.x as f32).round()
                        as i32,
                y: properties.placement.position.y
                    + (self.top_left_corner_crop_y * properties.placement.size.y as f32).round()
                        as i32,
            },
            false => properties.placement.position,
        };
        VideoProperties {
            resolution: Vec2d {
                x: (properties.resolution.x as f32 * self.crop_width).round() as u32,
                y: (properties.resolution.y as f32 * self.crop_height).round() as u32,
            },
            placement: VideoPlacement {
                position: transformed_position,
                size: Vec2d {
                    x: (properties.placement.size.x as f32 * self.crop_width).round() as u32,
                    y: (properties.placement.size.y as f32 * self.crop_height).round() as u32,
                },
                z: properties.placement.z,
            },
        }
    }

    fn data(&self) -> &[u8] {
        bytemuck::cast_slice(std::slice::from_ref(self))
    }

    fn transformation_name() -> &'static str {
        "cropping"
    }

    fn transformation_name_dyn(&self) -> &'static str {
        "cropping"
    }

    fn shader_module(device: &wgpu::Device) -> wgpu::ShaderModule
    where
        Self: Sized,
    {
        device.create_shader_module(wgpu::include_wgsl!("cropping.wgsl"))
    }
}
