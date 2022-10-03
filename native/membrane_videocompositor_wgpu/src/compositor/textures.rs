#[repr(usize)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum YUVPlane {
    Y = 0,
    U,
    V,
}

pub struct Texture {
    desc: wgpu::TextureDescriptor<'static>,
    texture: wgpu::Texture,
    pub view: wgpu::TextureView,
    pub bind_group: Option<wgpu::BindGroup>,
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
                label: Some("texture bind group"),
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

pub struct YUVTextures {
    planes: [Texture; 3],
}

impl YUVTextures {
    pub fn new(
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

    pub fn upload_data(&self, queue: &wgpu::Queue, data: &[u8]) {
        let pixel_amount =
            (self[YUVPlane::Y].desc.size.width * self[YUVPlane::Y].desc.size.height) as usize;

        // in YUV420p, the first `pixel_amount` of bytes represents the Y plane,
        // the following `pixel_amount / 4` bytes represents the U plane,
        // and the last `pixel_amount / 4` bytes represents the V plane.

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

pub struct OutputTextures {
    textures: YUVTextures,
    buffers: [wgpu::Buffer; 3],
}

impl std::ops::Index<YUVPlane> for OutputTextures {
    type Output = Texture;

    fn index(&self, index: YUVPlane) -> &Self::Output {
        &self.textures[index]
    }
}

impl OutputTextures {
    fn padded(width: u32) -> u32 {
        width + (256 - (width % 256))
    }

    pub fn new(device: &wgpu::Device, width: u32, height: u32) -> Self {
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

    pub fn transfer_content_to_buffers(&self, encoder: &mut wgpu::CommandEncoder) {
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

    pub async fn download(&self, device: &wgpu::Device, buffer: &mut [u8]) {
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
            for (chunk, output) in buffer
                .chunks(Self::padded(self.textures[plane].desc.size.width) as usize)
                .zip(output.chunks_mut(self.textures[plane].desc.size.width as usize))
            {
                let chunk = &chunk[..self.textures[plane].desc.size.width as usize];
                output.copy_from_slice(chunk)
            }
        }

        for plane in [YUVPlane::Y, YUVPlane::U, YUVPlane::V] {
            self.buffers[plane as usize].unmap();
        }
    }
}
