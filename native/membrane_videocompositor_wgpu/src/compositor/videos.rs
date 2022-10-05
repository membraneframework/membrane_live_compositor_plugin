use wgpu::util::DeviceExt;

use super::color_converters::YUVToRGBAConverter;
use super::textures::{RGBATexture, YUVTextures};
use super::Vertex;

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 3, 
    1, 2, 3
];

pub struct InputVideo {
    yuv_textures: YUVTextures,
    rgba_texture: RGBATexture,
    vertices: wgpu::Buffer,
    indices: wgpu::Buffer,
    indices_len: u32,
}

impl InputVideo {
    pub fn new(
        device: &wgpu::Device,
        width: u32,
        height: u32,
        position: &[Vertex; 4],
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
        all_textures_bind_group_layout: &wgpu::BindGroupLayout,
    ) -> Self {
        let yuv_textures = YUVTextures::new(
            device,
            width,
            height,
            wgpu::TextureUsages::COPY_DST | wgpu::TextureUsages::TEXTURE_BINDING,
            Some(single_texture_bind_group_layout),
            Some(all_textures_bind_group_layout),
        );

        let rgba_texture =
            RGBATexture::new(device, width, height, single_texture_bind_group_layout);

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
            yuv_textures,
            rgba_texture,
            vertices,
            indices,
            indices_len: INDICES.len() as u32,
        }
    }

    pub fn upload_data(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        converter: &YUVToRGBAConverter,
        data: &[u8],
    ) {
        self.yuv_textures.upload_data(queue, data);
        converter.convert(device, queue, &self.yuv_textures, &self.rgba_texture);
    }
}

impl<'a> InputVideo {
    pub fn draw(&'a self, render_pass: &mut wgpu::RenderPass<'a>) {
        render_pass.set_bind_group(
            0,
            self.rgba_texture.texture.bind_group.as_ref().unwrap(),
            &[],
        );
        render_pass.set_index_buffer(self.indices.slice(..), wgpu::IndexFormat::Uint16);
        render_pass.set_vertex_buffer(0, self.vertices.slice(..));
        render_pass.draw_indexed(0..self.indices_len, 0, 0..1);
    }
}
