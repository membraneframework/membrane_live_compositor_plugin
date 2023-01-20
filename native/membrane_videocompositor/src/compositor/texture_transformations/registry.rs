//! Implements registry of all texture transformation pipelines.
//! It's allow to access transformation pipeline based on passed
//! TextureTransformation struct.

use std::{any::TypeId, collections::HashMap};

use super::{
    texture_transformation_pipeline::TextureTransformationPipeline, TextureTransformation,
};

pub struct TextureTransformationRegistry(HashMap<TypeId, TextureTransformationPipeline>);

impl TextureTransformationRegistry {
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
        Self(HashMap::new())
    }

    pub fn register<T: TextureTransformation>(
        &mut self,
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) {
        let Self(map) = self;

        map.insert(
            TypeId::of::<T>(),
            TextureTransformationPipeline::new::<T>(device, single_texture_bind_group_layout),
        );
    }

    pub fn get(
        &self,
        transformation: &dyn TextureTransformation,
    ) -> &TextureTransformationPipeline {
        match self.get_from_typeid(transformation.type_id()) {
            Some(texture_transformation_pipeline) => texture_transformation_pipeline,
            None => panic!(
                "Transformation pipeline of {:#?} hasn't been registered!",
                transformation
            ),
        }
    }

    fn get_from_typeid(&self, id: TypeId) -> Option<&TextureTransformationPipeline> {
        self.0.get(&id)
    }
}