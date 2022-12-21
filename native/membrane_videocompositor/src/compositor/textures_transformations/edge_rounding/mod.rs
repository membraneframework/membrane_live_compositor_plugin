use bytemuck::{Pod, Zeroable};

#[derive(Debug, Clone, Copy, Zeroable, Pod)]
#[repr(C)]
pub struct EdgeRoundingUniform {
    pub video_width: f32,
    pub video_height: f32,
    pub edge_rounding_radius: f32,
}

impl EdgeRoundingUniform {
    pub fn get_blank_uniform() -> Self {
        return  EdgeRoundingUniform {
            video_width: 0.0,
            video_height: 0.0,
            edge_rounding_radius: 0.0
        };
    }
}
