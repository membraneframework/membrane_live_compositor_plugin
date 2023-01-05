use bytemuck::{Pod, Zeroable};

use crate::compositor::{vec2d::Vec2d, VideoPlacement, VideoProperties};

use super::TextureTransformation;

/// Struct representing parameters for video cropping texture transformation.
/// top_left_corner represents the coords of the top left corner of cropped (visible)
/// part of the video (in x ∈ [0,1], y ∈ [0, 1] proportion range).
/// crop_width represents the width of the cropped video (visible part) in [0, 1] relative range.
/// crop_height represents the height of the cropped video (visible part) in [0, 1] relative range.
#[derive(Debug, Clone, Copy, Zeroable, Pod, PartialEq)]
#[repr(C)]
pub struct Cropping {
    pub top_left_corner_crop_x: f32,
    pub top_left_corner_crop_y: f32,
    pub crop_width: f32,
    pub crop_height: f32,
}

impl TextureTransformation for Cropping {
    fn update_video_properties(&mut self, _properties: VideoProperties) {}

    fn transform_video_properties(&self, properties: VideoProperties) -> VideoProperties {
        VideoProperties {
            resolution: Vec2d {
                x: (properties.resolution.x as f32 * self.crop_width).round() as u32,
                y: (properties.resolution.y as f32 * self.crop_height).round() as u32,
            },
            placement: VideoPlacement {
                position: Vec2d {
                    x: properties.placement.position.x
                        + (self.top_left_corner_crop_x * properties.placement.size.x as f32).round()
                            as i32,
                    y: properties.placement.position.y
                        + (self.top_left_corner_crop_y * properties.placement.size.y as f32).round()
                            as i32,
                },
                size: Vec2d {
                    x: (properties.placement.size.x as f32 * self.crop_width).round() as u32,
                    y: (properties.placement.size.y as f32 * self.crop_height).round() as u32,
                },
                z: properties.placement.z,
            },
        }
    }

    fn buffer_size() -> usize
    where
        Self: Sized,
    {
        std::mem::size_of::<Self>()
    }

    fn data(&self) -> &[u8] {
        bytemuck::cast_slice(std::slice::from_ref(self))
    }

    fn shader_module(device: &wgpu::Device) -> wgpu::ShaderModule
    where
        Self: Sized,
    {
        device.create_shader_module(wgpu::include_wgsl!("cropping.wgsl"))
    }
}
