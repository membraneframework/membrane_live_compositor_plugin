use bytemuck::{Pod, Zeroable};

use crate::compositor::VideoProperties;

use super::Transformation;

/// Struct representing parameters for video corners rounding transformation.
/// border_radius is value representing the radius of the circle in pixels "cutting"
/// frame corner part.
#[derive(Debug, Clone, Copy, Zeroable, Pod, PartialEq)]
#[repr(C)]
pub struct CornersRounding {
    pub border_radius: f32,
    pub video_width: f32,
    pub video_height: f32,
}

impl Transformation for CornersRounding {
    fn update_video_properties(&mut self, properties: VideoProperties) {
        self.video_width = properties.placement.size.x as f32;
        self.video_height = properties.placement.size.y as f32;
    }

    fn transform_video_properties(&self, properties: VideoProperties) -> VideoProperties {
        properties
    }

    fn shader_module(device: &wgpu::Device) -> wgpu::ShaderModule {
        device.create_shader_module(wgpu::include_wgsl!("corners_rounding.wgsl"))
    }

    fn data(&self) -> &[u8] {
        bytemuck::cast_slice(std::slice::from_ref(self))
    }

    fn transformation_name() -> &'static str {
        "corners rounding"
    }

    fn transformation_name_dyn(&self) -> &'static str {
        "corners rounding"
    }
}
