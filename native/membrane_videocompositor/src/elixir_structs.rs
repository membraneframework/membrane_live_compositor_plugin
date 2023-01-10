use rustler::NifUntaggedEnum;

use crate::compositor::math::Vec2d;
use crate::compositor::texture_transformations::corners_rounding::CornersRounding;
use crate::compositor::texture_transformations::cropping::Cropping;
use crate::compositor::texture_transformations::{set_video_properties, TextureTransformation};
use crate::compositor::{self, VideoPlacement, VideoProperties};
use crate::{atoms, convert_z};

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.RustStructs.RawVideo"]
pub struct ElixirRawVideo {
    pub width: u32,
    pub height: u32,
    pub pixel_format: rustler::Atom,
    pub framerate: (u64, u64),
}

#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.RustStructs.BaseVideoPlacement"]
pub struct ElixirBaseVideoPlacement {
    pub position: (i32, i32),
    pub size: (u32, u32),
    pub z_value: f32,
}

impl ElixirBaseVideoPlacement {
    pub fn to_rust_placement(self) -> VideoPlacement {
        compositor::VideoPlacement {
            position: Vec2d {
                x: self.position.0,
                y: self.position.1,
            },
            size: Vec2d {
                x: self.size.0,
                y: self.size.1,
            },
            z: convert_z(self.z_value),
        }
    }
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
    ) -> Vec<Box<dyn TextureTransformation>> {
        let mut texture_transformations = Vec::new();

        for texture_transformation in self.texture_transformations.into_iter() {
            texture_transformations.push(texture_transformation.into_uniform(properties));
        }

        set_video_properties(properties, &mut texture_transformations);
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
    pub fn into_uniform(self, properties: VideoProperties) -> Box<dyn TextureTransformation> {
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
    fn into_uniform(self, properties: VideoProperties) -> Box<dyn TextureTransformation> {
        Box::new(CornersRounding {
            corner_rounding_radius: self.corner_rounding_radius,
            video_width_height_ratio: properties.placement.size.x as f32
                / properties.placement.size.y as f32,
        })
    }
}

/// Elixir struct wrapping parameters describing cropping texture transformation
#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.VideoTransformations.TextureTransformations.Cropping"]
pub struct ElixirCropping {
    pub crop_top_left_corner: (f32, f32),
    pub crop_size: (f32, f32),
    pub cropped_video_position: rustler::Atom,
}

impl ElixirCropping {
    fn into_uniform(self) -> Box<dyn TextureTransformation> {
        let transform_position: u32;

        if self.cropped_video_position == atoms::crop_part_position() {
            transform_position = 1;
        } else if self.cropped_video_position == atoms::input_position() {
            transform_position = 0;
        } else {
            panic!("Unsupported elixir positioning format");
        }

        Box::new(Cropping {
            top_left_corner_crop_x: self.crop_top_left_corner.0,
            top_left_corner_crop_y: self.crop_top_left_corner.1,
            crop_width: self.crop_size.0,
            crop_height: self.crop_size.1,
            transform_position,
        })
    }
}
