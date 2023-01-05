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

pub trait TextureTransformation: Send + Sync + Debug + 'static {
    fn buffer_size() -> usize
    where
        Self: Sized;
    fn data(&self) -> &[u8];
    fn update_video_properties(&mut self, properties: VideoProperties);
    fn transform_video_properties(&self, properties: VideoProperties) -> VideoProperties;
    fn shader_module(device: &wgpu::Device) -> wgpu::ShaderModule
    where
        Self: Sized;

    fn type_id(&self) -> TypeId {
        TypeId::of::<Self>()
    }
}

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

pub fn filled_registry(
    device: &wgpu::Device,
    single_texture_bind_group_layout: &wgpu::BindGroupLayout,
) -> TextureTransformationRegistry {
    let mut registry = TextureTransformationRegistry::new();

    registry.register::<Cropping>(device, single_texture_bind_group_layout);
    registry.register::<CornersRounding>(device, single_texture_bind_group_layout);

    registry
}
