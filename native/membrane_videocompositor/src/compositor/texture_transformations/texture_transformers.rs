/// The module used for relieving users from the pain of creating 600+ lines long boilerplate
/// wgpu render pipeline descriptions for creating textures transformations.
/// When adding a new texture transformation user needs only to modify texture_transformations
/// module, without the burden of creating wgpu boilerplate.
use crate::compositor::{pipeline_utils::PipelineUtils, textures::RGBATexture, Vertex};

use super::{TextureTransformationName, TextureTransformationUniform};

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 2,
    2, 3, 0,
];

/// This is abstraction for texture transformation rendering pipeline.
/// It's created once for every type of texture transformation
/// and is kept in main compositor state. Using specific texture transformation
/// require calling transform function on created pipeline (TextureTransformer
/// struct instance) with TextureTransformationUniform struct instance
/// (passed to shader) describing transformation.
/// This way, we can apply the same type of texture transformation like
/// corner rounding or filer effect on multiple videos with different parameters
/// (e.x. edge rounding radius or filter color) without the need to construct multiple
/// rendering pipelines.
#[derive(Debug)]
pub struct TextureTransformer {
    pub pipeline: wgpu::RenderPipeline,
    pub common: PipelineUtils,
    pub uniform_buffer: wgpu::Buffer,
    pub uniform_bind_group: wgpu::BindGroup,
}

impl TextureTransformer {
    /// Creates a rendering pipeline for a specific transformation type defined
    /// by transformation name.
    pub fn new(
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
        transformation_name: TextureTransformationName,
    ) -> Self {
        #[allow(unused_variables)]
        // used for descriptive debugs / error logs
        let transformation_description = transformation_name.get_name();

        let blank_uniform = transformation_name.get_blank_texture_transformation_uniform();

        let common = PipelineUtils::new(device);

        let uniform_buffer = blank_uniform.create_uniform_buffer(device);

        let uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some(&format!(
                    "Texture transformer {transformation_description} uniform bind group layout"
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

        let uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some(&format!(
                "Texture transformer {transformation_description} uniform bind group layout"
            )),
            layout: &uniform_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: uniform_buffer.as_entire_binding(),
            }],
        });

        let shader_module = transformation_name.create_shader_module(device);

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some(&format!(
                "Texture transformer {transformation_description} pipeline layout"
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
                "Texture transformer {transformation_description} pipeline"
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

        Self {
            pipeline,
            common,
            uniform_buffer,
            uniform_bind_group,
        }
    }

    /// Called on TextureTransformer instance
    /// (representing rendering pipeline for the specific type of texture transformation)
    /// applies transformation with passed parameters on the src frame and saves it
    /// at dst frame.
    pub fn transform(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        src: &RGBATexture,
        dst: &RGBATexture,
        transformation_uniform: &TextureTransformationUniform,
    ) {
        let transformation_name = transformation_uniform.get_name();
        let transformation_description = transformation_name.get_name();

        transformation_uniform.write_buffer(queue, &self.uniform_buffer);

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("Texture transformer {transformation_description} encoder"),
        });

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some(&format!(
                    "Texture transformer {transformation_description} render pass"
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
