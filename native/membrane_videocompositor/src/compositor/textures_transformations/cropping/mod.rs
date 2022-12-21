use bytemuck::{Pod, Zeroable};

#[derive(Debug, Clone, Copy, Zeroable, Pod)]
#[repr(C)]
pub struct CroppingUniform {
    pub top_left_corner_crop_x: f32,
    pub top_left_corner_crop_y: f32,
    pub crop_width: f32,
    pub crop_height: f32
}

impl CroppingUniform {
    pub fn get_blank_uniform() -> Self {
        return CroppingUniform{
            top_left_corner_crop_x: 0.0,
            top_left_corner_crop_y: 0.0,
            crop_width: 1.0,
            crop_height: 1.0,
        };
    }
}