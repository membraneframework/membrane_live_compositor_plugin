#![allow(clippy::needless_borrow)]
#![allow(clippy::from_over_into)]
use rustler::NifUntaggedEnum;

use crate::compositor::math::Vec2d;
use crate::compositor::transformations::corners_rounding::CornersRounding;
use crate::compositor::transformations::cropping::Cropping;
use crate::compositor::transformations::Transformation;
use crate::compositor::{self, VideoPlacement};
use crate::elixir_bridge::{atoms, convert_z};

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.RustStructs.RawVideo"]
pub struct ElixirRawVideo {
    pub width: u32,
    pub height: u32,
    pub pixel_format: rustler::Atom,
    pub framerate: (u64, u64),
}

#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.BaseVideoPlacement"]
pub struct ElixirBaseVideoPlacement {
    pub position: (i32, i32),
    pub size: (u32, u32),
    pub z_value: f32,
}

impl Into<VideoPlacement> for ElixirBaseVideoPlacement {
    fn into(self) -> VideoPlacement {
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

/// Wraps video transformations parameters (wrapped in structs) into enum.
/// Allows passing to rust elixir transformation type,
/// which is algebraic sum type of all structs describing single
/// transformation.
/// As a developer adding new transformation, you need just to add
/// new enum value and implement new match arm converting elixir structs to
/// rust structs used in shader.
#[derive(Debug, NifUntaggedEnum, Clone, Copy)]
pub enum ElixirTextureTransformations {
    CornersRounding(ElixirCornersRounding),
    Cropping(ElixirCropping),
}

impl Into<Box<dyn Transformation>> for ElixirTextureTransformations {
    fn into(self) -> Box<dyn Transformation> {
        match self {
            ElixirTextureTransformations::CornersRounding(elixir_corners_rounding) => {
                elixir_corners_rounding.into()
            }
            ElixirTextureTransformations::Cropping(elixir_cropping) => elixir_cropping.into(),
        }
    }
}

/// Elixir struct wrapping parameters describing corner rounding transformation
#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.Transformations.CornersRounding"]
pub struct ElixirCornersRounding {
    pub border_radius: u32,
}

impl Into<Box<dyn Transformation>> for ElixirCornersRounding {
    fn into(self) -> Box<dyn Transformation> {
        Box::new(CornersRounding {
            border_radius: self.border_radius as f32,
            video_width: 0.0,  // will be updated in compositor
            video_height: 0.0, // will be updated in compositor
        })
    }
}

/// Elixir struct wrapping parameters describing cropping transformation
#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.Transformations.Cropping"]
pub struct ElixirCropping {
    pub crop_top_left_corner: (f32, f32),
    pub crop_size: (f32, f32),
    pub cropped_video_position: rustler::Atom,
}

impl From<ElixirCropping> for Box<dyn Transformation> {
    fn from(val: ElixirCropping) -> Self {
        let transform_position: bool;

        if val.cropped_video_position == atoms::crop_part_position() {
            transform_position = true;
        } else if val.cropped_video_position == atoms::input_position() {
            transform_position = false;
        } else {
            panic!("Unsupported elixir positioning format");
        }

        Box::new(Cropping::new(
            Vec2d {
                x: val.crop_top_left_corner.0,
                y: val.crop_top_left_corner.1,
            },
            Vec2d {
                x: val.crop_size.0,
                y: val.crop_size.1,
            },
            transform_position,
        ))
    }
}
