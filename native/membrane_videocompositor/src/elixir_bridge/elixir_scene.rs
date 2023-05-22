#![allow(clippy::needless_borrow)]
#![allow(clippy::from_over_into)]

use std::collections::HashMap;

use rustler::NifUntaggedEnum;

use crate::compositor::{
    scene::{Scene, VideoConfig},
    texture_transformations::TextureTransformation,
    Vec2d, VideoId, VideoPlacement,
};

use super::elixir_structs::{ElixirCornersRounding, ElixirCropping};

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.RustStructs.Scene"]
pub struct ElixirScene {
    pub videos_configs: HashMap<VideoId, ElixirVideoConfig>,
}

impl Into<Scene> for ElixirScene {
    fn into(self) -> Scene {
        let mut videos_configs: HashMap<u32, VideoConfig> = HashMap::new();

        for (id, elixir_config) in self.videos_configs {
            videos_configs.insert(id, elixir_config.into());
        }

        Scene { videos_configs }
    }
}

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.Scene.VideoConfig"]
pub struct ElixirVideoConfig {
    pub placement: ElixirBaseVideoPlacement,
    pub transformations: ElixirVideoTransformations,
}

impl Into<VideoConfig> for ElixirVideoConfig {
    fn into(self) -> VideoConfig {
        VideoConfig {
            placement: self.placement.into(),
            texture_transformations: self.transformations.into(),
        }
    }
}

#[derive(Debug, rustler::NifStruct, Clone, Copy)]
#[module = "Membrane.VideoCompositor.Scene.BaseVideoPlacement"]
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

/// Describes all transformations applied to video
#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.VideoTransformations"]
pub struct ElixirVideoTransformations {
    pub texture_transformations: Vec<ElixirTextureTransformations>,
}

impl Into<Vec<Box<dyn TextureTransformation>>> for ElixirVideoTransformations {
    fn into(self) -> Vec<Box<dyn TextureTransformation>> {
        let mut texture_transformations = Vec::new();

        for texture_transformation in self.texture_transformations.into_iter() {
            texture_transformations.push(texture_transformation.into());
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

impl Into<Box<dyn TextureTransformation>> for ElixirTextureTransformations {
    fn into(self) -> Box<dyn TextureTransformation> {
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
