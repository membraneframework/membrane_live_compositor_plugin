//! Module providing an abstraction over texture transformations, enabling creation of new
//! texture transformations easily.

use std::{any::TypeId, fmt::Debug};

pub mod corners_rounding;
pub mod cropping;
pub mod registry;
pub mod texture_transformation_pipeline;

use self::{
    corners_rounding::CornersRounding, cropping::Cropping, registry::TextureTransformationRegistry,
};

use super::VideoProperties;

/// Trait that each new texture transformation should implement.
/// Remember, that struct fields order in struct implementing this trait
/// should match the one in shader for data to be mapped correctly.
pub trait TextureTransformation: Send + Sync + Debug + 'static {
    /// Returns struct data sliced passed to shader.
    fn data(&self) -> &[u8];

    /// Set new video properties to struct with transformation parameters.
    /// Some transformations need processed frame properties to work correctly,
    /// that why it's update transformations every time video properties
    /// of processed frame changes.
    fn update_video_properties(&mut self, properties: VideoProperties);

    /// For given input video properties returns output video properties.
    /// When some texture transformation modify incoming frame properties
    /// it's necessary to handle those modifications in render loop.
    fn transform_video_properties(&self, properties: VideoProperties) -> VideoProperties;

    /// Returns shader module created from shader associated with texture transformation.
    fn shader_module(device: &wgpu::Device) -> wgpu::ShaderModule
    where
        Self: Sized;

    fn buffer_size() -> usize
    where
        Self: Sized,
    {
        std::mem::size_of::<Self>()
    }

    fn type_id(&self) -> TypeId {
        TypeId::of::<Self>()
    }
}

/// Updates transformations with video properties used at each
/// transformation. Returns video properties after all transformations.
/// It's necessary since some transformation require
/// information about video properties in render process (in shader) (e.g.
/// corners rounding transformation require input video width:height ratio)
/// and some transformations can modify video properties (e.g. cropping).
pub fn set_video_properties(
    base_properties: VideoProperties,
    transformations: &mut [Box<dyn TextureTransformation>],
) -> VideoProperties {
    transformations
        .iter_mut()
        .fold(base_properties, |properties, transformation| {
            transformation.update_video_properties(properties);
            transformation.transform_video_properties(properties)
        })
}

/// Create and returns registry with all available TextureTransformationsPipelines.
/// For each type of texture transformation registry create new pipeline.
pub fn filled_registry(
    device: &wgpu::Device,
    single_texture_bind_group_layout: &wgpu::BindGroupLayout,
) -> TextureTransformationRegistry {
    let mut registry = TextureTransformationRegistry::new();

    registry.register::<Cropping>(device, single_texture_bind_group_layout);
    registry.register::<CornersRounding>(device, single_texture_bind_group_layout);

    registry
}
