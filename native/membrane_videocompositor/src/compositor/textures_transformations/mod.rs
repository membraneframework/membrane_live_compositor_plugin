/// Module providing abstraction over texture transformations, enabling creating new
/// texture transformations easily.
pub mod texture_transformer;

pub mod corners_rounding;
pub mod cropping;

use std::collections::HashMap;

use self::corners_rounding::CornersRoundingUniform;
use self::cropping::CroppingUniform;
use self::texture_transformer::TextureTransformer;
use wgpu::util::DeviceExt;

/// Name describing texture transformation type.
#[derive(PartialEq, Eq, Hash, Debug, Copy, Clone)]
pub enum TextureTransformationName {
    EdgeRounder(),
    Cropper(),
}

impl TextureTransformationName {
    /// Returns blank struct describing passed texture transformation.
    /// Is used for determining buffer parameters when rendering pipeline is created for
    /// specific transformation type.
    /// As a user adding new transformation, you just need to add new match arm,
    /// returning TextureTransformationUniform with example transformation describing struct.
    pub fn get_blank_texture_transformation_uniform(self) -> TextureTransformationUniform {
        match self {
            TextureTransformationName::EdgeRounder() => {
                TextureTransformationUniform::CornerRounder(
                    CornersRoundingUniform::get_blank_uniform(),
                )
            }
            TextureTransformationName::Cropper() => {
                TextureTransformationUniform::Cropper(CroppingUniform::get_blank_uniform())
            }
        }
    }

    /// Returns shader module created based on shader file.
    /// It's necessary for creating new transformation rendering pipeline.
    /// As a user adding new transformation, you just need to add new match arm
    /// with analogous function call on wgpu device, passing path to shader
    /// used in created transformation.
    pub fn create_shader_module(self, device: &wgpu::Device) -> wgpu::ShaderModule {
        match self {
            TextureTransformationName::EdgeRounder() => device.create_shader_module(
                wgpu::include_wgsl!("corners_rounding/corners_rounding.wgsl"),
            ),
            TextureTransformationName::Cropper() => {
                device.create_shader_module(wgpu::include_wgsl!("cropping/cropping.wgsl"))
            }
        }
    }

    /// Returns name used to create rendering pipeline, used to improve debug / errors logs.
    /// As a user adding new transformation, you just need to add new match arm returning
    /// name used for describing rendering pipeline elements for that transformation.   
    pub fn get_name(self) -> &'static str {
        match self {
            TextureTransformationName::EdgeRounder() => "Edge rounder",
            TextureTransformationName::Cropper() => "Cropper",
        }
    }

    /// Returns all texture transformers. Used in compositor module to put all texture transformers
    /// into state in order to only once initialize texture transformations pipelines.
    /// As a user adding new transformation, you just need to add analogous new insert to
    /// texture_transformers hashmap with TextureTransformationName as key and TextureTransformer as a value.  
    pub fn get_all_texture_transformers(
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> HashMap<TextureTransformationName, TextureTransformer> {
        let mut texture_transformers = HashMap::new();

        texture_transformers.insert(
            TextureTransformationName::EdgeRounder(),
            TextureTransformer::new(
                &device,
                single_texture_bind_group_layout,
                TextureTransformationName::EdgeRounder(),
            ),
        );
        texture_transformers.insert(
            TextureTransformationName::Cropper(),
            TextureTransformer::new(
                &device,
                single_texture_bind_group_layout,
                TextureTransformationName::Cropper(),
            ),
        );
        texture_transformers
    }
}

/// Enum wrapping structs passed to texture transformations shaders.
/// As a user adding new transformation, you just need to add analogous
/// enum value.
#[derive(Debug, Clone, Copy)]
pub enum TextureTransformationUniform {
    CornerRounder(CornersRoundingUniform),
    Cropper(CroppingUniform),
}

impl TextureTransformationUniform {
    /// Returns uniform buffer used in texture transformation render pipeline.
    /// As a user adding new transformation, you just need to add analogous
    /// call on wgpu device.
    pub fn create_uniform_buffer(self, device: &wgpu::Device) -> wgpu::Buffer {
        match self {
            TextureTransformationUniform::CornerRounder(edge_rounding_uniform) => device
                .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("edge rounding uniform buffer"),
                    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                    contents: bytemuck::cast_slice(&[edge_rounding_uniform]),
                }),
            TextureTransformationUniform::Cropper(cropping_uniform) => {
                device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("cropping uniform buffer"),
                    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                    contents: bytemuck::cast_slice(&[cropping_uniform]),
                })
            }
        }
    }

    /// Writes buffer with struct describing texture transformation to queue, making it
    /// accessible in shader.
    /// As a user adding new transformation, you just need to write analogous
    /// match arm calling write_buffer function on queue.
    pub fn write_buffer(self, queue: &wgpu::Queue, uniform_buffer: &wgpu::Buffer) {
        match self {
            TextureTransformationUniform::CornerRounder(edge_rounding_uniform) => queue
                .write_buffer(
                    uniform_buffer,
                    0,
                    bytemuck::cast_slice(&[edge_rounding_uniform]),
                ),
            TextureTransformationUniform::Cropper(cropping_uniform) => {
                queue.write_buffer(uniform_buffer, 0, bytemuck::cast_slice(&[cropping_uniform]))
            }
        }
    }

    /// Returns TextureTransformer identified by TextureTransformationUniform.
    /// As a user adding new transformation, you just need to write analogous
    /// match arm returning TextureTransformer from map.
    pub fn get_texture_transformer(
        self,
        texture_transformers: &HashMap<TextureTransformationName, TextureTransformer>,
    ) -> &TextureTransformer {
        match self {
            TextureTransformationUniform::CornerRounder(_) => texture_transformers
                .get(&TextureTransformationName::EdgeRounder())
                .unwrap(),
            TextureTransformationUniform::Cropper(_) => texture_transformers
                .get(&TextureTransformationName::Cropper())
                .unwrap(),
        }
    }
}
