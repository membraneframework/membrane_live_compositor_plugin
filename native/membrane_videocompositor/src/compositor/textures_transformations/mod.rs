pub mod edge_rounding;
pub mod cropping;

use std::f64::consts::E;
use std::io::Seek;

use bytemuck::Pod;
use wgpu::Device;
use wgpu::{util::DeviceExt};
use self::edge_rounding::{EdgeRoundingUniform};
use self::cropping::{CroppingUniform};
use crate::compositor::Vertex;
use crate::compositor::common::Common;

use super::textures::RGBATexture;

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 2,
    2, 3, 0,
];

#[derive(PartialEq, Eq, Hash)]
pub enum TextureTransformerName {
    EdgeRounder(),
    Cropper(),
}

impl TextureTransformerName {
    pub fn get_black_texture_transformation_uniform(self) -> TextureTransformationUniform {
        return match self {
            TextureTransformerName::EdgeRounder() => 
                TextureTransformationUniform::EdgeRounder(EdgeRoundingUniform::get_blank_uniform()),
            TextureTransformerName::Cropper() =>
                TextureTransformationUniform::Cropper(CroppingUniform::get_blank_uniform()),
        }
    }
}


#[derive(Debug, Clone)]
pub enum TextureTransformationUniform {
    EdgeRounder(EdgeRoundingUniform),
    Cropper(CroppingUniform)
}

impl TextureTransformationUniform {
    pub fn create_uniform_buffer(self, device: &wgpu::Device) -> wgpu::Buffer {
        return match self {
            TextureTransformationUniform::EdgeRounder(edge_rounding_uniform) => 
                device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("edge rounding uniform buffer"),
                    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                    contents: bytemuck::cast_slice(&[edge_rounding_uniform]),
                }),
            TextureTransformationUniform::Cropper(cropping_uniform) => 
                device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
                    label: Some("cropping uniform buffer"),
                    usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                    contents: bytemuck::cast_slice(&[cropping_uniform]),
                }),
        }
    }

    pub fn write_buffer(self, queue: &wgpu::Queue, uniform_buffer: &wgpu::Buffer) {
        match self {
            TextureTransformationUniform::EdgeRounder(edge_rounding_uniform) => 
                queue.write_buffer(
                    uniform_buffer,
                    0,
                    bytemuck::cast_slice(&[edge_rounding_uniform])
                ),
            TextureTransformationUniform::Cropper(cropping_uniform) => 
                queue.write_buffer(
                    uniform_buffer,
                    0,
                    bytemuck::cast_slice(&[cropping_uniform])
                ),
        }
    }
}

pub struct TextureTransformer {
    pub pipeline: wgpu::RenderPipeline,
    pub common: Common,
    pub uniform_buffer: wgpu::Buffer,
    pub uniform_bind_group: wgpu::BindGroup,
}

impl TextureTransformer {
    pub fn new(
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
        transformation_name: TextureTransformerName
    ) -> Self {
        let black_uniform = transformation_name.get_black_texture_transformation_uniform();

        let common = Common::new(device);

        let uniform_buffer = black_uniform.create_uniform_buffer(device);

        let uniform_bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("{transformation_description} uniform bind group layout"),
            entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    count: None,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                }
            ],
        });

        let uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("{transformation_description} uniform bind group layout"),
            layout: &uniform_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: uniform_buffer.as_entire_binding()
                }
            ],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("{transformation_description} pipeline layout"),
            bind_group_layouts: &[
                single_texture_bind_group_layout,
                &common.sampler_bind_group_layout,
                &uniform_bind_group_layout,
            ],
            push_constant_ranges: &[],
        });

        let shader_module = match transformation_name {
            TextureTransformerName::EdgeRounder() => 
                device.create_shader_module(wgpu::include_wgsl!("edge_rounding/edge_rounding.wgsl")),
            TextureTransformerName::Cropper() => 
                device.create_shader_module(wgpu::include_wgsl!("edge_rounding/edge_rounding.wgsl")),
        };

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("{transformation_description} pipeline"),
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
            pipeline: pipeline,
            common: common,
            uniform_buffer: uniform_buffer,
            uniform_bind_group: uniform_bind_group,
        }
    }

    pub fn transform(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        src: &RGBATexture,
        dst: &RGBATexture,
        transformation_uniform: TextureTransformationUniform
    ) {

        transformation_uniform.write_buffer(queue, &self.uniform_buffer);

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("Edge rounder encoder"),
        });

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Edge rounder render pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
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