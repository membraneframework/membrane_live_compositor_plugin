use super::color_converters::RGBAToYUVConverter;

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
    bytes_per_pixel: u32,
    pub view: wgpu::TextureView,
    pub bind_group: Option<wgpu::BindGroup>,
}

impl Texture {
    fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        usage: wgpu::TextureUsages,
        format: wgpu::TextureFormat,
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
            format,
            usage,
            mip_level_count: 1,
            sample_count: 1,
        };

        let texture = device.create_texture(&desc);

        let view = texture.create_view(&wgpu::TextureViewDescriptor {
            label: Some("y texture view"),
            dimension: Some(wgpu::TextureViewDimension::D2),
            format: Some(format),
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

        let bytes_per_pixel = match format {
            wgpu::TextureFormat::R8Unorm => 1,
            wgpu::TextureFormat::Rgba8Unorm => 4,
            _ => unimplemented!(),
        };

        Self {
            desc,
            texture,
            view,
            bind_group,
            bytes_per_pixel,
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
                bytes_per_row: std::num::NonZeroU32::new(
                    self.desc.size.width * self.bytes_per_pixel,
                ),
                rows_per_image: std::num::NonZeroU32::new(self.desc.size.height),
            },
            self.desc.size,
        );
    }
}

pub struct YUVTextures {
    planes: [Texture; 3],
    pub bind_group: Option<wgpu::BindGroup>,
}

impl YUVTextures {
    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        usage: wgpu::TextureUsages,
        single_texture_bind_group_layout: Option<&wgpu::BindGroupLayout>,
        all_textures_bind_group_layout: Option<&wgpu::BindGroupLayout>,
    ) -> Self {
        let planes = [
            Texture::new(
                device,
                width,
                height,
                usage,
                wgpu::TextureFormat::R8Unorm,
                single_texture_bind_group_layout,
            ),
            Texture::new(
                device,
                width / 2,
                height / 2,
                usage,
                wgpu::TextureFormat::R8Unorm,
                single_texture_bind_group_layout,
            ),
            Texture::new(
                device,
                width / 2,
                height / 2,
                usage,
                wgpu::TextureFormat::R8Unorm,
                single_texture_bind_group_layout,
            ),
        ];

        let bind_group = all_textures_bind_group_layout.map(|layout| {
            device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("yuv all textures bind group"),
                layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: wgpu::BindingResource::TextureView(&planes[0].view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 1,
                        resource: wgpu::BindingResource::TextureView(&planes[1].view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 2,
                        resource: wgpu::BindingResource::TextureView(&planes[2].view),
                    },
                ],
            })
        });

        Self { planes, bind_group }
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
    pub rgba_texture: RGBATexture,
    yuv_textures: YUVTextures,
    buffers: [wgpu::Buffer; 3],
}

// impl std::ops::Index<YUVPlane> for OutputTextures {
//     type Output = Texture;

//     fn index(&self, index: YUVPlane) -> &Self::Output {
//         &self.yuv_textures[index]
//     }
// }

impl OutputTextures {
    fn padded(width: u32) -> u32 {
        width + (256 - (width % 256))
    }

    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        Self {
            rgba_texture: RGBATexture::new(device, width, height, single_texture_bind_group_layout),

            yuv_textures: YUVTextures::new(
                device,
                width,
                height,
                wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::COPY_SRC,
                None,
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

    pub fn transfer_content_to_buffers(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        converter: &RGBAToYUVConverter,
    ) {
        converter.convert(device, queue, &self.rgba_texture, &self.yuv_textures);

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("transfer result yuv texture to buffers encoder"),
        });

        for plane in [YUVPlane::Y, YUVPlane::U, YUVPlane::V] {
            encoder.copy_texture_to_buffer(
                wgpu::ImageCopyTexture {
                    aspect: wgpu::TextureAspect::All,
                    mip_level: 0,
                    origin: wgpu::Origin3d::ZERO,
                    texture: &self.yuv_textures[plane].texture,
                },
                wgpu::ImageCopyBuffer {
                    buffer: &self.buffers[plane as usize],
                    layout: wgpu::ImageDataLayout {
                        bytes_per_row: std::num::NonZeroU32::new(Self::padded(
                            self.yuv_textures[plane].desc.size.width,
                        )),
                        rows_per_image: std::num::NonZeroU32::new(
                            self.yuv_textures[plane].desc.size.height,
                        ),
                        offset: 0,
                    },
                },
                self.yuv_textures[plane].desc.size,
            )
        }

        queue.submit(Some(encoder.finish()));
    }

    pub async fn download(&self, device: &wgpu::Device, buffer: &mut [u8]) {
        let pixel_amount = self.yuv_textures[YUVPlane::Y].desc.size.width as usize
            * self.yuv_textures[YUVPlane::Y].desc.size.height as usize;
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
                .chunks(Self::padded(self.yuv_textures[plane].desc.size.width) as usize)
                .zip(output.chunks_mut(self.yuv_textures[plane].desc.size.width as usize))
            {
                let chunk = &chunk[..self.yuv_textures[plane].desc.size.width as usize];
                output.copy_from_slice(chunk)
            }
        }

        for plane in [YUVPlane::Y, YUVPlane::U, YUVPlane::V] {
            self.buffers[plane as usize].unmap();
        }
    }
}

pub struct RGBATexture {
    pub texture: Texture,
}

impl RGBATexture {
    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let texture = Texture::new(
            device,
            width,
            height,
            wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING,
            wgpu::TextureFormat::Rgba8Unorm,
            Some(bind_group_layout),
        );

        Self { texture }
    }
}
