// TO COMPLETE
pub struct EdgeRounder {
    pipeline: wgpu::RenderPipeline,
    common: Common
}

impl EdgeRounder {
    pub fn new(
        device: &wgpu::Device,
        edge_rounder_textures_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let common = Common::new(device);

        let shader_module = device.create_shader_module(wgpu::include_wgsl!("edge_rounding_shader.wgsl"));

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Edge rounding pipeline layout"),
            bind_group_layouts: &[
                edges_rounding_bind_group_layout,
                &common.sampler_bind_group_layout,
            ],
            push_constant_ranges: &[],
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Edge rounding pipeline"),
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

    pub fn round_edges(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        src: &RGBATextures,
        dst: &RGBATexture,
    ) {
        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("Edge rounder encoder"),
        });

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Edge rounding pass"),
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
