use bytemuck::{Pod, Zeroable};

#[derive(Debug, Clone, Copy, Zeroable, Pod)]
#[repr(C)]
pub struct CornerRoundingUniform {
    pub video_resolution: [f32; 2],
    pub edge_rounding_radius: f32,
}

impl CornerRoundingUniform {
    pub fn get_blank_uniform() -> Self {
        return CornerRoundingUniform {
            video_resolution: [1920.0, 1080.0],
            edge_rounding_radius: 0.0,
        };
    }
}
