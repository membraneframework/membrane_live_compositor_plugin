use bytemuck::{Pod, Zeroable};

use crate::compositor::VideoProperties;

/// Struct representing parameters for video corners rounding texture transformation.
/// corner_rounding_radius is [0, 1] range float representing the radius of the circle "cutting"
/// frame corner part. [0, 1] range is mapped into pixels based on video width, meaning
/// corner_rounding_radius equals 0.1 in FullHD video makes 192 pixels long radius of circles.
#[derive(Debug, Clone, Copy, Zeroable, Pod, PartialEq)]
#[repr(C)]
pub struct CornersRoundingUniform {
    pub corner_rounding_radius: f32,
    pub video_width_height_ratio: f32,
}

impl CornersRoundingUniform {
    pub fn get_blank_uniform() -> Self {
        CornersRoundingUniform {
            corner_rounding_radius: 0.0,
            video_width_height_ratio: 0.0,
        }
    }

    pub fn set_properties(&mut self, properties: VideoProperties) {
        self.video_width_height_ratio =
            properties.resolution.x as f32 / properties.resolution.y as f32;
    }

    pub fn transform_properties(self, properties: VideoProperties) -> VideoProperties {
        properties
    }
}
