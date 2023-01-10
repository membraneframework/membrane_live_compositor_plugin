//! The module is used for relieving users from the pain of creating 600+ lines long boilerplate
//! wgpu render pipeline descriptions for creating textures transformations.
//! When adding a new texture transformation user needs only to modify texture_transformations
//! module, without the burden of creating wgpu boilerplate.

use crate::compositor::{pipeline_common::PipelineCommon, textures::RGBATexture, Vertex};
use std::any::TypeId;

use super::TextureTransformation;

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 2,
    2, 3, 0,
];

/// This an is abstraction for texture transformation rendering pipeline.
/// It's created once for every type of texture transformation
/// and is kept in main compositor state. Using specific texture transformation
/// require calling transform function on created pipeline (TextureTransformationPipeline
/// struct instance) with TextureTransformation struct instance
/// (passed to shader) describing transformation parameters.
/// This way, we can apply the same type of texture transformation like
/// corner rounding or filer effect on multiple videos with different parameters
/// (e.x. edge rounding radius or filter color) without the need to construct multiple
/// rendering pipelines.
#[derive(Debug)]
pub struct TextureTransformationPipeline {
    pub pipeline: wgpu::RenderPipeline,
    pub common: PipelineCommon,
    pub uniform_bind_group: wgpu::BindGroup,
    uniform: wgpu::Buffer,
    transformation_id: TypeId,
}

impl TextureTransformationPipeline {
    /// Creates a rendering pipeline for a specific transformation type.
    pub fn new<T: super::TextureTransformation>(
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let common = PipelineCommon::new(device);

        let uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some(&format!(
                    "Texture transformation pipeline {} uniform bind group layout",
                    stringify!(T)
                )),
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    count: None,
                    visibility: wgpu::ShaderStages::FRAGMENT | wgpu::ShaderStages::VERTEX,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                }],
            });

        let shader_module = T::shader_module(device);

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some(&format!(
                "Texture transformation pipeline {} pipeline layout",
                stringify!(T),
            )),
            bind_group_layouts: &[
                single_texture_bind_group_layout,
                &common.sampler_bind_group_layout,
                &uniform_bind_group_layout,
            ],
            push_constant_ranges: &[],
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some(&format!(
                "Texture transformation pipeline {} pipeline",
                stringify!(T),
            )),
            layout: Some(&pipeline_layout),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: Some(wgpu::Face::Back),
                strip_index_format: None,
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            vertex: wgpu::VertexState {
                module: &shader_module,
                entry_point: "vs_main",
                buffers: &[Vertex::LAYOUT],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader_module,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    blend: Some(wgpu::BlendState::REPLACE), // REPLACE to keep transparent parts not blended with cleared background
                    write_mask: wgpu::ColorWrites::all(),
                    format: wgpu::TextureFormat::Rgba8Unorm,
                })],
            }),
            multisample: wgpu::MultisampleState {
                count: 1,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            multiview: None,
            depth_stencil: None,
        });

        let uniform = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some(&format!(
                "Texture transformation pipeline {} uniform buffer",
                stringify!(T),
            )),
            mapped_at_creation: false,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::UNIFORM,
            size: std::mem::size_of::<T>() as u64,
        });

        let uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some(&format!(
                "Texture transformation pipeline {} uniform bind group",
                stringify!(T)
            )),
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: uniform.as_entire_binding(),
            }],
            layout: &uniform_bind_group_layout,
        });

        Self {
            pipeline,
            common,
            uniform_bind_group,
            uniform,
            transformation_id: TypeId::of::<T>(),
        }
    }

    /// Called on TextureTransformationPipeline instance
    /// applies transformation with passed parameters on the src frame and saves it
    /// at the dst frame.
    pub fn transform(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        src: &RGBATexture,
        dst: &RGBATexture,
        transformation: &dyn TextureTransformation,
    ) {
        assert_eq!(self.transformation_id, transformation.type_id(), "TextureTransformationPipeline: transform() called with a transformation of an incorrect type");
        // FIXME: handle the case of T.data().len() != T::buffer_size()

        queue.write_buffer(&self.uniform, 0, transformation.data());

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some(&format!(
                "Texture transformation pipeline {} encoder",
                stringify!(T),
            )),
        });

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some(&format!(
                    "Texture transformation pipeline {} render pass",
                    stringify!(T),
                )),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::WHITE),
                        store: true,
                    },
                    view: &dst.texture.view,
                    resolve_target: None,
                })],
                depth_stencil_attachment: None,
            });

            render_pass.set_pipeline(&self.pipeline);
            render_pass.set_bind_group(0, src.texture.bind_group.as_ref().unwrap(), &[]);
            render_pass.set_bind_group(1, &self.common.sampler_bind_group, &[]);
            render_pass.set_bind_group(2, &self.uniform_bind_group, &[]);
            render_pass.set_vertex_buffer(0, self.common.vertex_buffer.slice(..));
            render_pass.set_index_buffer(
                self.common.index_buffer.slice(..),
                wgpu::IndexFormat::Uint16,
            );
            render_pass.draw_indexed(0..INDICES.len() as u32, 0, 0..1);
        }

        queue.submit(Some(encoder.finish()));
    }
}
