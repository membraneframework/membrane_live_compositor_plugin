use bytemuck::{Pod, Zeroable};
use wgpu::util::DeviceExt;

use crate::compositor::Vertex;
use crate::compositor::common::Common;
use super::{textures::RGBATexture, Vec2d};

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 2,
    2, 3, 0,
];

#[derive(Debug, Clone, Copy, Zeroable, Pod)]
#[repr(C)]
struct EdgeRounderUniform {
    video_width: f32,
    video_height: f32,
    edge_rounding_radius: f32,
}


pub struct EdgeRounder {
    pipeline: wgpu::RenderPipeline,
    common: Common,
    edge_rounder_unform_buffer: wgpu::Buffer,
    edge_rounder_bind_group: wgpu::BindGroup,
}

impl EdgeRounder {
    pub fn new(
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let common = Common::new(device);

        let edge_rounder_uniform = EdgeRounderUniform {
            video_width: 0.0 as f32, 
            video_height: 0.0 as f32, 
            edge_rounding_radius: 0.0 as f32
        };

        let edge_rounder_uniform_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Edge rounder uniform buffer"),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            contents: bytemuck::cast_slice(&[edge_rounder_uniform]),
        });

        let edge_rounder_uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("Edge rounder uniform bind group layout"),
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

        let edge_rounder_uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Edge rounder uniform bind group layout"),
            layout: &edge_rounder_uniform_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: edge_rounder_uniform_buffer.as_entire_binding()
                }
            ],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("edge rounder pipeline layout"),
            bind_group_layouts: &[
                single_texture_bind_group_layout,
                &common.sampler_bind_group_layout,
                &edge_rounder_uniform_bind_group_layout,
            ],
            push_constant_ranges: &[],
        });

        let shader_module = device.create_shader_module(wgpu::include_wgsl!("edge_rounding.wgsl"));

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("edge rounding pipeline"),
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
                    blend: Some(wgpu::BlendState::REPLACE),
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
            edge_rounder_unform_buffer: edge_rounder_uniform_buffer,
            edge_rounder_bind_group: edge_rounder_uniform_bind_group,
        }
    }

    pub fn transform(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        src: &RGBATexture,
        dst: &RGBATexture,
        video_resolution: Vec2d<u32>,
        edge_rounding_radius: f32
    ) {

        let edge_rounding_uniform = EdgeRounderUniform {
            video_width: video_resolution.x as f32, 
            video_height: video_resolution.y as f32,
            edge_rounding_radius: edge_rounding_radius
        };

        queue.write_buffer(
            &self.edge_rounder_unform_buffer,
            0,
            bytemuck::cast_slice(&[edge_rounding_uniform])
        );

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
            render_pass.set_bind_group(2, &self.edge_rounder_bind_group, &[]);
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
