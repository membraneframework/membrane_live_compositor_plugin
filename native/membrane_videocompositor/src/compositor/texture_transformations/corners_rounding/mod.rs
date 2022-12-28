use bytemuck::{Pod, Zeroable};

use crate::compositor::VideoProperties;

#[derive(Debug, Clone, Copy, Zeroable, Pod, PartialEq)]
#[repr(C)]
pub struct CornersRoundingUniform {
    pub video_width_height_ratio: f32,
    pub corner_rounding_radius: f32,
}

impl CornersRoundingUniform {
    pub fn get_blank_uniform() -> Self {
        CornersRoundingUniform {
            video_width_height_ratio: 0.0,
            corner_rounding_radius: 0.0,
        }
    }

    pub fn set_properties(mut self, properties: VideoProperties) {
        self.video_width_height_ratio =
            properties.resolution.x as f32 / properties.resolution.y as f32;
    }

    pub fn update_properties(self, properties: VideoProperties) -> VideoProperties {
        properties
    }
}
