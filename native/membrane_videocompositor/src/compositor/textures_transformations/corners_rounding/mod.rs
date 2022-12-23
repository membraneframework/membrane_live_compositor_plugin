use bytemuck::{Pod, Zeroable};

#[derive(Debug, Clone, Copy, Zeroable, Pod)]
#[repr(C)]
pub struct CornersRoundingUniform {
    pub video_width_height_ratio: f32,
    pub corner_rounding_radius: f32,
}

impl CornersRoundingUniform {
    pub fn get_blank_uniform() -> Self {
        return CornersRoundingUniform {
            video_width_height_ratio: 16.0 / 9.0,
            corner_rounding_radius: 0.0,
        };
    }
}
