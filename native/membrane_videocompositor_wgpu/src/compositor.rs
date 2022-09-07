use wgpu::util::DeviceExt;

pub struct State {
    device: wgpu::Device,
    input_videos: [InputVideo; 2],
    output_textures: OutputTextures,
    pipeline: wgpu::RenderPipeline,
    queue: wgpu::Queue,
    _sampler: wgpu::Sampler,
    sampler_bind_group: wgpu::BindGroup,
}

impl State {
    pub async fn new(
        upper_caps: &crate::RawVideo,
        lower_caps: &crate::RawVideo,
        output_caps: &crate::RawVideo,
    ) -> State {
        let instance = wgpu::Instance::new(wgpu::Backends::all());
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                compatible_surface: None,
                force_fallback_adapter: false,
                power_preference: wgpu::PowerPreference::HighPerformance,
            })
            .await
            .unwrap();

        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    label: Some("device"),
                    features: wgpu::Features::empty(),
                    limits: wgpu::Limits::default(),
                },
                None,
            )
            .await
            .unwrap();

        let texture_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("texture bind group layout"),
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    count: None,
                }],
            });

        let input_videos = [
            InputVideo::new(
                &device,
                upper_caps.width as u32,
                upper_caps.height as u32,
                &UPPER_VERTICES,
                &texture_bind_group_layout,
            ),
            InputVideo::new(
                &device,
                lower_caps.width as u32,
                lower_caps.height as u32,
                &LOWER_VERTICES,
                &texture_bind_group_layout,
            ),
        ];

        let output_textures =
            OutputTextures::new(&device, output_caps.width as u32, output_caps.height as u32);

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("sampler"),
            address_mode_u: wgpu::AddressMode::ClampToEdge,
            address_mode_v: wgpu::AddressMode::ClampToEdge,
            address_mode_w: wgpu::AddressMode::ClampToEdge,
            min_filter: wgpu::FilterMode::Nearest,
            mag_filter: wgpu::FilterMode::Nearest,
            mipmap_filter: wgpu::FilterMode::Nearest,
            ..Default::default()
        });

        let sampler_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("sampler bind group layout"),
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    count: None,
                }],
            });

        let sampler_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("sampler bind group"),
            layout: &sampler_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::Sampler(&sampler),
            }],
        });

        let shader_module = device.create_shader_module(wgpu::include_wgsl!("shader.wgsl"));

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("pipeline"),
            bind_group_layouts: &[&texture_bind_group_layout, &sampler_bind_group_layout],
            push_constant_ranges: &[],
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("pipeline"),
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
                    blend: None,
                    write_mask: wgpu::ColorWrites::RED,
                    format: wgpu::TextureFormat::R8Unorm,
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
            device,
            input_videos,
            output_textures,
            pipeline,
            queue,
            _sampler: sampler,
            sampler_bind_group,
        }
    }

    pub async fn join_frames(
        &self,
        upper_frame: &[u8],
        lower_frame: &[u8],
        output_buffer: &mut [u8],
    ) {
        self.input_videos[0].upload_data(&self.queue, upper_frame);
        self.input_videos[1].upload_data(&self.queue, lower_frame);

        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("encoder"),
            });

        for plane in [YUVPlane::Y, YUVPlane::U, YUVPlane::V] {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("i dont know yet"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &self.output_textures.textures[plane].view,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: true,
                    },
                    resolve_target: None,
                })],
                depth_stencil_attachment: None,
            });

            render_pass.set_pipeline(&self.pipeline);
            render_pass.set_bind_group(1, &self.sampler_bind_group, &[]);

            for video in &self.input_videos {
                video.draw(&mut render_pass, plane)
            }
        }

        self.output_textures
            .transfer_content_to_buffers(&mut encoder);
        self.queue.submit(Some(encoder.finish()));

        self.output_textures
            .download(&self.device, output_buffer)
            .await;
    }
}

#[repr(usize)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum YUVPlane {
    Y = 0,
    U,
    V,
}

struct Texture {
    desc: wgpu::TextureDescriptor<'static>,
    texture: wgpu::Texture,
    view: wgpu::TextureView,
    bind_group: Option<wgpu::BindGroup>,
}

impl Texture {
    fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        usage: wgpu::TextureUsages,
        bind_group_layout: Option<&wgpu::BindGroupLayout>,
    ) -> Self {
        let desc = wgpu::TextureDescriptor {
            label: Some("texture"),
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::R8Unorm,
            usage,
            mip_level_count: 1,
            sample_count: 1,
        };

        let texture = device.create_texture(&desc);

        let view = texture.create_view(&wgpu::TextureViewDescriptor {
            label: Some("y texture view"),
            dimension: Some(wgpu::TextureViewDimension::D2),
            format: Some(wgpu::TextureFormat::R8Unorm),
            mip_level_count: std::num::NonZeroU32::new(1),
            base_array_layer: 0,
            base_mip_level: 0,
            array_layer_count: std::num::NonZeroU32::new(1),
            aspect: wgpu::TextureAspect::All,
        });

        let bind_group = bind_group_layout.map(|layout| {
            device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: None,
                layout,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(&view),
                }],
            })
        });

        Self {
            desc,
            texture,
            view,
            bind_group,
        }
    }

    fn upload_data(&self, queue: &wgpu::Queue, data: &[u8]) {
        queue.write_texture(
            wgpu::ImageCopyTexture {
                aspect: wgpu::TextureAspect::All,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                texture: &self.texture,
            },
            data,
            wgpu::ImageDataLayout {
                offset: 0,
                bytes_per_row: std::num::NonZeroU32::new(self.desc.size.width),
                rows_per_image: std::num::NonZeroU32::new(self.desc.size.height),
            },
            self.desc.size,
        );
    }
}

struct YUVTextures {
    planes: [Texture; 3],
}

impl YUVTextures {
    fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        usage: wgpu::TextureUsages,
        bind_group_layout: Option<&wgpu::BindGroupLayout>,
    ) -> Self {
        Self {
            planes: [
                Texture::new(device, width, height, usage, bind_group_layout),
                Texture::new(device, width / 2, height / 2, usage, bind_group_layout),
                Texture::new(device, width / 2, height / 2, usage, bind_group_layout),
            ],
        }
    }

    fn upload_data(&self, queue: &wgpu::Queue, data: &[u8]) {
        let pixel_amount =
            (self[YUVPlane::Y].desc.size.width * self[YUVPlane::Y].desc.size.height) as usize;

        assert_eq!(data.len(), pixel_amount * 3 / 2);

        let planes = [
            &data[..pixel_amount],
            &data[pixel_amount..pixel_amount * 5 / 4],
            &data[pixel_amount * 5 / 4..pixel_amount * 3 / 2],
        ];

        for (texture, data) in self.planes.iter().zip(planes) {
            texture.upload_data(queue, data);
        }
    }
}

impl std::ops::Index<YUVPlane> for YUVTextures {
    type Output = Texture;

    fn index(&self, index: YUVPlane) -> &Self::Output {
        &self.planes[index as usize]
    }
}

struct OutputTextures {
    textures: YUVTextures,
    buffers: [wgpu::Buffer; 3],
}

impl OutputTextures {
    fn padded(width: u32) -> u32 {
        width + (256 - (width % 256))
    }

    fn new(device: &wgpu::Device, width: u32, height: u32) -> Self {
        Self {
            textures: YUVTextures::new(
                device,
                width,
                height,
                wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::COPY_SRC,
                None,
            ),
            buffers: [
                device.create_buffer(&wgpu::BufferDescriptor {
                    label: Some("output texture buffer 0"),
                    mapped_at_creation: false,
                    usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
                    size: (Self::padded(width) * height) as u64,
                }),
                device.create_buffer(&wgpu::BufferDescriptor {
                    label: Some("output texture buffer 1"),
                    mapped_at_creation: false,
                    usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
                    size: (Self::padded(width / 2) * height / 2) as u64,
                }),
                device.create_buffer(&wgpu::BufferDescriptor {
                    label: Some("output texture buffer 2"),
                    mapped_at_creation: false,
                    usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
                    size: (Self::padded(width / 2) * height / 2) as u64,
                }),
            ],
        }
    }

    fn transfer_content_to_buffers(&self, encoder: &mut wgpu::CommandEncoder) {
        for plane in [YUVPlane::Y, YUVPlane::U, YUVPlane::V] {
            encoder.copy_texture_to_buffer(
                wgpu::ImageCopyTexture {
                    aspect: wgpu::TextureAspect::All,
                    mip_level: 0,
                    origin: wgpu::Origin3d::ZERO,
                    texture: &self.textures[plane].texture,
                },
                wgpu::ImageCopyBuffer {
                    buffer: &self.buffers[plane as usize],
                    layout: wgpu::ImageDataLayout {
                        bytes_per_row: std::num::NonZeroU32::new(Self::padded(
                            self.textures[plane].desc.size.width,
                        )),
                        rows_per_image: std::num::NonZeroU32::new(
                            self.textures[plane].desc.size.height,
                        ),
                        offset: 0,
                    },
                },
                self.textures[plane].desc.size,
            )
        }
    }

    async fn download(&self, device: &wgpu::Device, buffer: &mut [u8]) {
        let pixel_amount = self.textures[YUVPlane::Y].desc.size.width as usize
            * self.textures[YUVPlane::Y].desc.size.height as usize;
        assert_eq!(buffer.len(), pixel_amount * 3 / 2);

        let (y, rest) = buffer.split_at_mut(pixel_amount);
        let (u, v) = rest.split_at_mut(pixel_amount / 4);
        let outputs = [y, u, v];

        for (&plane, output) in [YUVPlane::Y, YUVPlane::U, YUVPlane::V].iter().zip(outputs) {
            let (tx, rx) = futures_intrusive::channel::shared::oneshot_channel();
            self.buffers[plane as usize]
                .slice(..)
                .map_async(wgpu::MapMode::Read, move |res| tx.send(res).unwrap());

            device.poll(wgpu::MaintainBase::Wait);
            rx.receive().await.unwrap().unwrap();

            let buffer = self.buffers[plane as usize].slice(..).get_mapped_range();
            buffer
                .chunks(Self::padded(self.textures[plane].desc.size.width) as usize)
                .flat_map(|chunk| &chunk[..self.textures[plane].desc.size.width as usize])
                .zip(output.iter_mut())
                .for_each(|(val, slot)| *slot = *val);
        }

        for plane in [YUVPlane::Y, YUVPlane::U, YUVPlane::V] {
            self.buffers[plane as usize].unmap();
        }
    }
}

struct InputVideo {
    textures: YUVTextures,
    vertices: wgpu::Buffer,
    indices: wgpu::Buffer,
    indices_len: u32,
}

impl InputVideo {
    fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        position: &[Vertex; 4],
        texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let textures = YUVTextures::new(
            device,
            width,
            height,
            wgpu::TextureUsages::COPY_DST | wgpu::TextureUsages::TEXTURE_BINDING,
            Some(texture_bind_group_layout),
        );

        let vertices = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: None,
            contents: bytemuck::cast_slice(position),
            usage: wgpu::BufferUsages::VERTEX,
        });

        let indices = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: None,
            contents: bytemuck::cast_slice(&INDICES),
            usage: wgpu::BufferUsages::INDEX,
        });

        Self {
            textures,
            vertices,
            indices,
            indices_len: INDICES.len() as u32,
        }
    }

    fn upload_data(&self, queue: &wgpu::Queue, data: &[u8]) {
        self.textures.upload_data(queue, data);
    }
}

impl<'a> InputVideo {
    fn draw(&'a self, render_pass: &mut wgpu::RenderPass<'a>, plane: YUVPlane) {
        render_pass.set_bind_group(0, self.textures[plane].bind_group.as_ref().unwrap(), &[]);
        render_pass.set_index_buffer(self.indices.slice(..), wgpu::IndexFormat::Uint16);
        render_pass.set_vertex_buffer(0, self.vertices.slice(..));
        render_pass.draw_indexed(0..self.indices_len, 0, 0..1);
    }
}

#[repr(C)]
#[derive(Debug, Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
struct Vertex {
    position: [f32; 3],
    texture_coords: [f32; 2],
}

impl Vertex {
    const LAYOUT: wgpu::VertexBufferLayout<'static> = wgpu::VertexBufferLayout {
        array_stride: std::mem::size_of::<Vertex>() as u64,
        step_mode: wgpu::VertexStepMode::Vertex,
        attributes: &wgpu::vertex_attr_array![0 => Float32x3, 1 => Float32x2],
    };
}

const UPPER_VERTICES: [Vertex; 4] = [
    Vertex {
        position: [1.0, 1.0, 0.0],
        texture_coords: [1.0, 0.0],
    },
    Vertex {
        position: [-1.0, 1.0, 0.0],
        texture_coords: [0.0, 0.0],
    },
    Vertex {
        position: [-1.0, 0.0, 0.0],
        texture_coords: [0.0, 1.0],
    },
    Vertex {
        position: [1.0, 0.0, 0.0],
        texture_coords: [1.0, 1.0],
    },
];

const LOWER_VERTICES: [Vertex; 4] = [
    Vertex {
        position: [1.0, 0.0, 0.0],
        texture_coords: [1.0, 0.0],
    },
    Vertex {
        position: [-1.0, 0.0, 0.0],
        texture_coords: [0.0, 0.0],
    },
    Vertex {
        position: [-1.0, -1.0, 0.0],
        texture_coords: [0.0, 1.0],
    },
    Vertex {
        position: [1.0, -1.0, 0.0],
        texture_coords: [1.0, 1.0],
    },
];

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 3, 
    1, 2, 3
];
