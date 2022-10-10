use crate::{
    errors::{
        Error::{self, UploadDataSizeMismatch},
        Result,
    },
    BindGroupAttachment,
};

pub struct Texture {
    bytes_per_pixel: u32,
    pub descriptor: wgpu::TextureDescriptor<'static>,
    texture: wgpu::Texture,
    pub view: wgpu::TextureView,
}

impl Texture {
    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        format: wgpu::TextureFormat,
        usage: wgpu::TextureUsages,
    ) -> Self {
        let descriptor = wgpu::TextureDescriptor {
            label: Some("texture"),
            dimension: wgpu::TextureDimension::D2,
            format,
            mip_level_count: 1,
            sample_count: 1,
            usage,
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
        };

        // FIXME: perhaps we should track usage flags and only allow upload/download
        //        operations when those were specified in the usage flags

        let texture = device.create_texture(&descriptor);

        let view = texture.create_view(&wgpu::TextureViewDescriptor {
            label: Some("texture view"),
            array_layer_count: std::num::NonZeroU32::new(1),
            aspect: wgpu::TextureAspect::All,
            base_array_layer: 0,
            base_mip_level: 0,
            dimension: Some(wgpu::TextureViewDimension::D2),
            format: Some(format),
            mip_level_count: std::num::NonZeroU32::new(1),
        });

        let bytes_per_pixel = match format {
            wgpu::TextureFormat::R8Unorm => 1,
            wgpu::TextureFormat::Rgba8Unorm => 4,
            _ => unimplemented!(),
        };

        Self {
            bytes_per_pixel,
            descriptor,
            texture,
            view,
        }
    }

    fn size(&self) -> u64 {
        self.descriptor.size.width as u64
            * self.descriptor.size.height as u64
            * self.bytes_per_pixel as u64
    }

    fn padded(x: u32) -> u32 {
        if x % 256 == 0 {
            x
        } else {
            x + (256 - (x % 256))
        }
    }

    pub fn upload(&self, queue: &wgpu::Queue, data: &[u8]) -> Result<()> {
        if data.len() != self.size() as usize {
            return Err(UploadDataSizeMismatch);
        }

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
                    self.descriptor.size.width * self.bytes_per_pixel,
                ),
                rows_per_image: std::num::NonZeroU32::new(self.descriptor.size.height),
            },
            self.descriptor.size,
        );

        Ok(())
    }

    pub async fn download(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        output: &mut [u8],
    ) -> Result<()> {
        if self.size() > output.len() as u64 {
            return Err(Error::DownloadBufferTooSmall);
        }

        let bytes_per_row = self.descriptor.size.width * self.bytes_per_pixel;

        // FIXME: Perhaps it would be a performance opportunity to not allocate this buffer every download.
        //        It's also possible that this is optimized in the driver to be very cheap if we allocate
        //        and deallocate buffers of the same size.
        let buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("temporary download buffer"),
            mapped_at_creation: false,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            size: (Self::padded(bytes_per_row) * self.descriptor.size.height) as u64,
        });

        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("download encoder"),
        });
        encoder.copy_texture_to_buffer(
            wgpu::ImageCopyTexture {
                aspect: wgpu::TextureAspect::All,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                texture: &self.texture,
            },
            wgpu::ImageCopyBuffer {
                buffer: &buffer,
                layout: wgpu::ImageDataLayout {
                    offset: 0,
                    bytes_per_row: std::num::NonZeroU32::new(Self::padded(bytes_per_row)),
                    rows_per_image: std::num::NonZeroU32::new(self.descriptor.size.height),
                },
            },
            self.descriptor.size,
        );

        queue.submit(Some(encoder.finish()));

        let (tx, rx) = futures::channel::oneshot::channel();

        buffer
            .slice(..)
            .map_async(wgpu::MapMode::Read, move |res| tx.send(res).unwrap());

        device.poll(wgpu::MaintainBase::Wait);
        rx.await.unwrap().unwrap();
        {
            let mapped_buffer = buffer.slice(..).get_mapped_range();

            mapped_buffer
                .chunks(Self::padded(bytes_per_row) as usize)
                .map(|chunk| &chunk[..bytes_per_row as usize])
                .zip(output.chunks_mut(bytes_per_row as usize))
                .for_each(|(buffer_chunk, output_chunk)| {
                    output_chunk.copy_from_slice(buffer_chunk)
                });
        }

        buffer.unmap();

        Ok(())
    }
}

impl BindGroupAttachment for Texture {
    fn binding_type() -> wgpu::BindingType {
        wgpu::BindingType::Texture {
            sample_type: wgpu::TextureSampleType::Float { filterable: true },
            view_dimension: wgpu::TextureViewDimension::D2,
            multisampled: false,
        }
    }

    fn binding_resource(&self) -> wgpu::BindingResource {
        wgpu::BindingResource::TextureView(&self.view)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils;

    #[test]
    fn upload_and_download() {
        let (device, queue) = test_utils::initialize_wgpu();

        let texture = Texture::new(
            &device,
            2,
            3,
            wgpu::TextureFormat::Rgba8Unorm,
            wgpu::TextureUsages::COPY_SRC | wgpu::TextureUsages::COPY_DST,
        );

        #[rustfmt::skip]
        let data: &[u8] = &[
            0x00, 0x00, 0x00, 0xff, 
            0x21, 0x21, 0x21, 0x21, 
            0x37, 0x37, 0x37, 0x37, 
            0x42, 0x42, 0x42, 0x42, 
            0x13, 0x37, 0x13, 0x37, 
            0x01, 0x02, 0x03, 0x04,
        ];

        texture.upload(&queue, data).unwrap();
        let mut downloaded = vec![0; 24];
        pollster::block_on(texture.download(&device, &queue, &mut downloaded)).unwrap();

        assert_eq!(data, downloaded);
    }
}
