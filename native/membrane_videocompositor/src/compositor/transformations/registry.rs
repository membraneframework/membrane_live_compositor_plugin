//! Implements registry of all transformation pipelines.
//! It's allow to access transformation pipeline based on passed
//! TextureTransformation struct.

use std::{any::TypeId, collections::HashMap};

use super::{pipeline::TransformationPipeline, Transformation};

pub struct TransformationRegistry(HashMap<TypeId, TransformationPipeline>);

impl TransformationRegistry {
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
        Self(HashMap::new())
    }

    pub fn register<T: Transformation>(
        &mut self,
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) {
        let Self(map) = self;

        map.insert(
            TypeId::of::<T>(),
            TransformationPipeline::new::<T>(device, single_texture_bind_group_layout),
        );
    }

    pub fn get(&self, transformation: &dyn Transformation) -> &TransformationPipeline {
        match self.get_from_typeid(transformation.type_id()) {
            Some(texture_transformation_pipeline) => texture_transformation_pipeline,
            None => {
                panic!("Transformation pipeline of {transformation:#?} hasn't been registered!")
            }
        }
    }

    fn get_from_typeid(&self, id: TypeId) -> Option<&TransformationPipeline> {
        self.0.get(&id)
    }
}
