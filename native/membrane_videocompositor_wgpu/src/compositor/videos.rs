use wgpu::util::DeviceExt;

use super::textures::{YUVPlane, YUVTextures};
use super::Vertex;

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 3, 
    1, 2, 3
];

pub struct InputVideo {
    textures: YUVTextures,
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
            label: Some("video vertex buffer"),
            contents: bytemuck::cast_slice(position),
            usage: wgpu::BufferUsages::VERTEX,
        });

        let indices = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("video index buffer"),
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

    pub fn upload_data(&self, queue: &wgpu::Queue, data: &[u8]) {
        self.textures.upload_data(queue, data);
    }
}

impl<'a> InputVideo {
    pub fn draw(&'a self, render_pass: &mut wgpu::RenderPass<'a>, plane: YUVPlane) {
        render_pass.set_bind_group(0, self.textures[plane].bind_group.as_ref().unwrap(), &[]);
        render_pass.set_index_buffer(self.indices.slice(..), wgpu::IndexFormat::Uint16);
        render_pass.set_vertex_buffer(0, self.vertices.slice(..));
        render_pass.draw_indexed(0..self.indices_len, 0, 0..1);
    }
}
