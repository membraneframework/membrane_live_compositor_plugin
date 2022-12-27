#![allow(clippy::needless_borrow)]

use rustler::NifUntaggedEnum;

use crate::compositor::textures_transformations::corners_rounding::CornersRoundingUniform;
use crate::compositor::textures_transformations::cropping::CroppingUniform;
use crate::compositor::textures_transformations::TextureTransformationUniform;
use crate::compositor::VideoProperties;

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.RustStructs.RawVideo"]
pub struct ElixirRawVideo {
    pub width: u32,
    pub height: u32,
    pub pixel_format: rustler::Atom,
    pub framerate: (u64, u64),
}

#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.RustStructs.VideoPlacement"]
pub struct ElixirVideoPlacement {
    pub position: (u32, u32),
    pub display_size: (u32, u32),
    pub z_value: f32,
}

/// Describes all transformations applied to video
#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.VideoTransformations"]
pub struct ElixirVideoTransformations {
    pub texture_transformations: Vec<ElixirTextureTransformations>,
}

impl ElixirVideoTransformations {
    pub fn get_texture_transformations(
        self,
        properties: VideoProperties,
    ) -> Vec<TextureTransformationUniform> {
        let mut texture_transformations = Vec::new();

        for texture_transformation in self.texture_transformations.into_iter() {
            texture_transformations.push(texture_transformation.into_uniform(properties))
        }
        texture_transformations
    }
}

/// Wraps video transformations parameters (wrapped in structs) into enum.
/// Allows passing to rust elixir texture transformation type,
/// which is algebraic sum type of all structs describing single
/// texture transformation.
/// As a developer adding new texture transformation, you need just to add
/// new enum value and implement new match arm converting elixir structs to
/// rust structs used in shader.
#[derive(Debug, NifUntaggedEnum, Clone, Copy)]
pub enum ElixirTextureTransformations {
    CornersRounding(ElixirCornersRounding),
    Cropping(ElixirCropping),
}

impl ElixirTextureTransformations {
    pub fn into_uniform(self, properties: VideoProperties) -> TextureTransformationUniform {
        match self {
            ElixirTextureTransformations::CornersRounding(elixir_corners_rounding) => {
                elixir_corners_rounding.into_uniform(properties)
            }
            ElixirTextureTransformations::Cropping(elixir_cropping) => {
                elixir_cropping.into_uniform()
            }
        }
    }
}
/// Elixir struct wrapping parameters describing corner rounding texture transformation
#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding"]
pub struct ElixirCornersRounding {
    pub corner_rounding_radius: f32,
}

impl ElixirCornersRounding {
    fn into_uniform(self, properties: VideoProperties) -> TextureTransformationUniform {
        TextureTransformationUniform::CornerRounder(CornersRoundingUniform {
            video_width_height_ratio: properties.placement.size.x as f32
                / properties.placement.size.y as f32,
            corner_rounding_radius: self.corner_rounding_radius,
        })
    }
}

/// Elixir struct wrapping parameters describing cropping texture transformation
#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping"]
pub struct ElixirCropping {
    pub top_left_corner: (f32, f32),
    pub crop_size: (f32, f32),
}

impl ElixirCropping {
    fn into_uniform(self) -> TextureTransformationUniform {
        TextureTransformationUniform::Cropper(CroppingUniform {
            top_left_corner_crop_x: self.top_left_corner.0,
            top_left_corner_crop_y: self.top_left_corner.1,
            crop_width: self.crop_size.0,
            crop_height: self.crop_size.1,
        })
    }
}
