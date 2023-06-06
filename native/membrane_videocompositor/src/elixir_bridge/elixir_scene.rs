#![allow(clippy::needless_borrow)]
#![allow(clippy::from_over_into)]

use std::collections::HashMap;

use rustler::NifUntaggedEnum;

use crate::compositor::{
    scene::{Scene, VideoConfig},
    transformations::Transformation,
    Vec2d, VideoId, VideoPlacement,
};

use super::elixir_structs::{ElixirCornersRounding, ElixirCropping};

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.RustStructs.Scene"]
pub struct ElixirScene {
    pub video_configs: HashMap<VideoId, ElixirVideoConfig>,
}

impl Into<Scene> for ElixirScene {
    fn into(self) -> Scene {
        let mut video_configs: HashMap<u32, VideoConfig> = HashMap::new();

        for (id, elixir_config) in self.video_configs {
            video_configs.insert(id, elixir_config.into());
        }

        Scene { video_configs }
    }
}

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.VideoConfig"]
pub struct ElixirVideoConfig {
    pub placement: ElixirBaseVideoPlacement,
    pub transformations: Vec<ElixirTextureTransformations>,
}

impl Into<VideoConfig> for ElixirVideoConfig {
    fn into(self) -> VideoConfig {
        let mut transformations = Vec::new();

        for texture_transformation in self.transformations.into_iter() {
            transformations.push(texture_transformation.into());
        }

        VideoConfig {
            placement: self.placement.into(),
            transformations,
        }
    }
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
        VideoPlacement {
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

pub fn convert_z(z: f32) -> f32 {
    // we need to do this because 0.0 is an intuitively standard value and maps onto 1.0,
    // which is outside of the wgpu clip space
    1.0 - z.max(1e-7)
}
