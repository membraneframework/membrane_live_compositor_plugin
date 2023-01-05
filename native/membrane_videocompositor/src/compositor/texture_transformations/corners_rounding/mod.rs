use bytemuck::{Pod, Zeroable};

use crate::compositor::VideoProperties;

use super::TextureTransformation;

/// Struct representing parameters for video corners rounding texture transformation.
/// corner_rounding_radius is [0, 1] range float representing the radius of the circle "cutting"
/// frame corner part. [0, 1] range is mapped into pixels based on video width, meaning
/// corner_rounding_radius equals 0.1 in FullHD video makes 192 pixels long radius of circles.
#[derive(Debug, Clone, Copy, Zeroable, Pod, PartialEq)]
#[repr(C)]
pub struct CornersRounding {
    pub corner_rounding_radius: f32,
    pub video_width_height_ratio: f32,
}

impl TextureTransformation for CornersRounding {
    fn update_video_properties(&mut self, properties: VideoProperties) {
        self.video_width_height_ratio =
            properties.resolution.x as f32 / properties.resolution.y as f32;
    }

    fn transform_video_properties(&self, properties: VideoProperties) -> VideoProperties {
        properties
    }

    fn shader_module(device: &wgpu::Device) -> wgpu::ShaderModule {
        device.create_shader_module(wgpu::include_wgsl!("corners_rounding.wgsl"))
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
}
