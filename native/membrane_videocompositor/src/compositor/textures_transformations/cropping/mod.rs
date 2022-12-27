use bytemuck::{Pod, Zeroable};

/// Struct representing parameters for video cropping texture transformation.
/// top_left_corner represents coords of top left corner of cropped (visible)
/// part of the video (in x ∈ [0,1], y ∈ [0, 1] proportion range).
/// crop_width represents width of cropped video (visible part) in [0, 1] relative range.
/// crop_height represents height of cropped video (visible part) in [0, 1] relative range.
#[derive(Debug, Clone, Copy, Zeroable, Pod)]
#[repr(C)]
pub struct CroppingUniform {
    pub top_left_corner_crop_x: f32,
    pub top_left_corner_crop_y: f32,
    pub crop_width: f32,
    pub crop_height: f32,
}

impl CroppingUniform {
    pub fn get_blank_uniform() -> Self {
        CroppingUniform {
            top_left_corner_crop_x: 0.0,
            top_left_corner_crop_y: 0.0,
            crop_width: 1.0,
            crop_height: 1.0,
        }
    }
}
