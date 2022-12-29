/// Module providing an abstraction over texture transformations, enabling creation of new
/// texture transformations easily.
pub mod texture_transformers;

pub mod corners_rounding;
pub mod cropping;

use std::collections::HashMap;

use self::corners_rounding::CornersRoundingUniform;
use self::cropping::CroppingUniform;
use self::texture_transformers::TextureTransformer;
use wgpu::util::DeviceExt;

use super::VideoProperties;

/// Name describing texture transformation type.
#[derive(PartialEq, Eq, Hash, Debug, Copy, Clone)]
pub enum TextureTransformationName {
    CornersRounder,
    Cropper,
}

impl TextureTransformationName {
    /// Returns blank struct describing passed texture transformation.
    /// Is used for determining buffer parameters when the rendering pipeline is created for
    /// a specific transformation type.
    /// As a user adding a new transformation, you just need to add a new match arm,
    /// returning TextureTransformationUniform with example transformation describing struct.
    pub fn get_blank_texture_transformation_uniform(self) -> TextureTransformationUniform {
        match self {
            TextureTransformationName::CornersRounder => {
                TextureTransformationUniform::CornerRounder(
                    CornersRoundingUniform::get_blank_uniform(),
                )
            }
            TextureTransformationName::Cropper => {
                TextureTransformationUniform::Cropper(CroppingUniform::get_blank_uniform())
            }
        }
    }

    /// Returns shader module created based on shader file.
    /// It's necessary for creating a new transformation rendering pipeline.
    /// As a user adding a new transformation, you just need to add a new match arm
    /// with an analogous function call on the wgpu device, passing the path to the shader
    /// used in created transformation.
    pub fn create_shader_module(self, device: &wgpu::Device) -> wgpu::ShaderModule {
        match self {
            TextureTransformationName::CornersRounder => device.create_shader_module(
                wgpu::include_wgsl!("corners_rounding/corners_rounding.wgsl"),
            ),
            TextureTransformationName::Cropper => {
                device.create_shader_module(wgpu::include_wgsl!("cropping/cropping.wgsl"))
            }
        }
    }

    /// Returns name used to create rendering pipeline used to improve debug / error logs.
    /// As a user adding a new transformation, you just need to add a new match arm returning
    /// name used for describing rendering pipeline elements for that transformation.
    pub fn get_name(self) -> &'static str {
        match self {
            TextureTransformationName::CornersRounder => "Edge rounder",
            TextureTransformationName::Cropper => "Cropper",
        }
    }

    /// Returns all texture transformers. Used in compositor module to put all texture transformers
    /// into the state to only once initialize texture transformation pipelines.
    /// As a user adding a new transformation, you just need to add an analogous new insert to
    /// texture_transformers hashmap with TextureTransformationName as the key and TextureTransformer as a value.
    pub fn get_all_texture_transformers(
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> HashMap<TextureTransformationName, TextureTransformer> {
        let mut texture_transformers = HashMap::new();

        texture_transformers.insert(
            TextureTransformationName::CornersRounder,
            TextureTransformer::new(
                device,
                single_texture_bind_group_layout,
                TextureTransformationName::CornersRounder,
            ),
        );
        texture_transformers.insert(
            TextureTransformationName::Cropper,
            TextureTransformer::new(
                device,
                single_texture_bind_group_layout,
                TextureTransformationName::Cropper,
            ),
        );
        texture_transformers
    }
}

/// Enum wrapping structs passed to texture transformation shaders.
/// Variables order defined in the Uniform struct has to be the same in the shader file.
/// As a user adding a new transformation, you just need to add an analogous
/// enum value.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum TextureTransformationUniform {
    CornerRounder(CornersRoundingUniform),
    Cropper(CroppingUniform),
}

impl TextureTransformationUniform {
    pub fn get_name(self) -> TextureTransformationName {
        match self {
            TextureTransformationUniform::CornerRounder(_) => {
                TextureTransformationName::CornersRounder
            }
            TextureTransformationUniform::Cropper(_) => TextureTransformationName::Cropper,
        }
    }

    /// Updates transformations with video properties of input frame (some transformations require those
    /// information, e.g. corners rounding transformation require frame width height ratio).
    /// Returns video properties after texture transformation.
    pub fn update_texture_transformations(
        properties: VideoProperties,
        texture_transformations: &mut [TextureTransformationUniform],
    ) -> VideoProperties {
        let mut transformed_video_properties = properties;

        for texture_transformation in texture_transformations.iter_mut() {
            texture_transformation.set_video_properties(transformed_video_properties);
            transformed_video_properties =
                texture_transformation.transform_video_properties(transformed_video_properties);
        }
        transformed_video_properties
    }

    /// Updates TextureTransformationUniform with video properties. It's necessary, since some
    /// texture transformations can change video properties (e.g. cropping changes resolution and position)
    /// As a user adding new transformation, you just need to add an analogous
    /// match arm and handle set_properties function on transformation uniform struct,
    /// which updates it with new properties.
    pub fn set_video_properties(&mut self, properties: VideoProperties) {
        *self = match self {
            TextureTransformationUniform::CornerRounder(corners_rounding_uniform) => {
                corners_rounding_uniform.set_properties(properties);
                TextureTransformationUniform::CornerRounder(*corners_rounding_uniform)
            }
            TextureTransformationUniform::Cropper(cropping_uniform) => {
                cropping_uniform.set_properties(properties);
                TextureTransformationUniform::Cropper(*cropping_uniform)
            }
        };
    }

    /// Return video properties after transformation. It's necessary, since some transformations
    /// need video properties to work correctly (e.g. width-height proportion is needed in CornerRounding)
    /// As a user adding new transformation, you just need to add an analogous
    /// match arm and handle update_properties function on transformation uniform struct,
    /// which returns video properties after transformation.
    pub fn transform_video_properties(self, properties: VideoProperties) -> VideoProperties {
        match self {
            TextureTransformationUniform::CornerRounder(corners_rounding_uniform) => {
                corners_rounding_uniform.transform_properties(properties)
            }
            TextureTransformationUniform::Cropper(cropping_uniform) => {
                cropping_uniform.transform_properties(properties)
            }
        }
    }

    /// Returns uniform buffer used in texture transformation render pipeline.
    /// As a user adding new transformation, you just need to add analogous
    /// call on wgpu device.
    pub fn create_uniform_buffer(self, device: &wgpu::Device) -> wgpu::Buffer {
        match self {
            TextureTransformationUniform::CornerRounder(corners_rounding_uniform) => device
                .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("corners rounding uniform buffer"),
                    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                    contents: bytemuck::cast_slice(&[corners_rounding_uniform]),
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
    pub fn get_texture_transformer(
        self,
        texture_transformers: &HashMap<TextureTransformationName, TextureTransformer>,
    ) -> &TextureTransformer {
        texture_transformers.get(&self.get_name()).unwrap()
    }
}
