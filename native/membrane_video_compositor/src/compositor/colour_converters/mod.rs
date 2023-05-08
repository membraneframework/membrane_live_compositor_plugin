use membrane_video_compositor_common::wgpu::{self, util::DeviceExt};

use crate::compositor::pipeline_common::PipelineCommon;
use crate::compositor::Vertex;

use super::textures::{RGBATexture, YUVPlane, YUVTextures};

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 2,
    2, 3, 0,
];

pub struct YUVToRGBAConverter {
    pipeline: wgpu::RenderPipeline,
    common: PipelineCommon,
}

impl YUVToRGBAConverter {
    pub fn new(
        device: &wgpu::Device,
        yuv_textures_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let common = PipelineCommon::new(device);

        let shader_module = device.create_shader_module(wgpu::include_wgsl!("yuv_to_rgba.wgsl"));

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("YUV to RGBA colour converter render pipeline layout"),
            bind_group_layouts: &[
                yuv_textures_bind_group_layout,
                &common.sampler_bind_group_layout,
            ],
            push_constant_ranges: &[],
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("YUV to RGBA colour converter render pipeline"),
            layout: Some(&pipeline_layout),
            primitive: wgpu::PrimitiveState {
                polygon_mode: wgpu::PolygonMode::Fill,
                topology: wgpu::PrimitiveTopology::TriangleList,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: Some(wgpu::Face::Back),
                strip_index_format: None,
                conservative: false,
                unclipped_depth: false,
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
                    format: wgpu::TextureFormat::Rgba8Unorm,
                    write_mask: wgpu::ColorWrites::all(),
                    blend: None,
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

        Self { pipeline, common }
    }

    pub fn convert(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        src: &YUVTextures,
        dst: &RGBATexture,
    ) {
        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("YUV to RGBA colour converter encoder"),
        });

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("YUV to RGBA colour converter render pass"),
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
            render_pass.set_bind_group(0, src.bind_group.as_ref().unwrap(), &[]);
            render_pass.set_bind_group(1, &self.common.sampler_bind_group, &[]);
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

pub struct RGBAToYUVConverter {
    pipeline: wgpu::RenderPipeline,
    plane_selector_buffer: wgpu::Buffer,
    plane_selector_bind_group: wgpu::BindGroup,
    common: PipelineCommon,
}

impl RGBAToYUVConverter {
    pub fn new(
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let common = PipelineCommon::new(device);

        let plane_selector_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("RGBA to YUV colour converter plane selector buffer"),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            contents: bytemuck::cast_slice(&[0u32]),
        });

        let plane_selector_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("RGBA to YUV colour converter plane selector bind group layout"),
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    count: None,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                }],
            });

        let plane_selector_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("RGBA to YUV colour converter plane selector bind group layout"),
            layout: &plane_selector_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::Buffer(wgpu::BufferBinding {
                    buffer: &plane_selector_buffer,
                    offset: 0,
                    size: std::num::NonZeroU64::new(std::mem::size_of::<u32>() as u64),
                }),
            }],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("RGBA to YUV colour converter pipeline layout"),
            bind_group_layouts: &[
                single_texture_bind_group_layout,
                &common.sampler_bind_group_layout,
                &plane_selector_bind_group_layout,
            ],
            push_constant_ranges: &[],
        });

        let shader_module = device.create_shader_module(wgpu::include_wgsl!("rgba_to_yuv.wgsl"));

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("RGBA to YUV colour converter pipeline"),
            layout: Some(&pipeline_layout),
            primitive: wgpu::PrimitiveState {
                polygon_mode: wgpu::PolygonMode::Fill,
                topology: wgpu::PrimitiveTopology::TriangleList,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: Some(wgpu::Face::Back),
                strip_index_format: None,
                conservative: false,
                unclipped_depth: false,
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
                    format: wgpu::TextureFormat::R8Unorm,
                    write_mask: wgpu::ColorWrites::all(),
                    blend: None,
                })],
            }),
            depth_stencil: None,
            multisample: wgpu::MultisampleState {
                count: 1,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            multiview: None,
        });

        Self {
            common,
            pipeline,
            plane_selector_buffer,
            plane_selector_bind_group,
        }
    }

    pub fn convert(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        src: &RGBATexture,
        dst: &YUVTextures,
    ) {
        for plane in [YUVPlane::Y, YUVPlane::U, YUVPlane::V] {
            queue.write_buffer(
                &self.plane_selector_buffer,
                0,
                bytemuck::cast_slice(&[plane as u32]),
            );

            let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("RGBA to YUV colour converter command encoder"),
            });

            {
                let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                    label: Some("YUV to RGBA colour converter render pass"),
                    color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                        ops: wgpu::Operations {
                            // We want the background to be black. Black in YUV is y = 0, u = 0.5, v = 0.5
                            // Therefore, we set the clear color to 0, 0, 0 when drawing the y plane
                            // and to 0.5, 0.5, 0.5 when drawing the u and v planes.
                            load: wgpu::LoadOp::Clear(if plane == YUVPlane::Y {
                                wgpu::Color {
                                    r: 0.0,
                                    g: 0.0,
                                    b: 0.0,
                                    a: 1.0,
                                }
                            } else {
                                wgpu::Color {
                                    r: 0.5,
                                    g: 0.5,
                                    b: 0.5,
                                    a: 1.0,
                                }
                            }),
                            store: true,
                        },
                        view: &dst[plane].view,
                        resolve_target: None,
                    })],
                    depth_stencil_attachment: None,
                });

                render_pass.set_pipeline(&self.pipeline);
                render_pass.set_bind_group(0, src.texture.bind_group.as_ref().unwrap(), &[]);
                render_pass.set_bind_group(1, &self.common.sampler_bind_group, &[]);
                render_pass.set_bind_group(2, &self.plane_selector_bind_group, &[]);
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
}
