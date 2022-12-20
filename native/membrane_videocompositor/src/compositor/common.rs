use crate::compositor::Vertex;
use wgpu::util::DeviceExt;

const VERTICES: [Vertex; 4] = [
    Vertex {
        position: [1.0, -1.0, 0.0],
        texture_coords: [1.0, 1.0],
    },
    Vertex {
        position: [1.0, 1.0, 0.0],
        texture_coords: [1.0, 0.0],
    },
    Vertex {
        position: [-1.0, 1.0, 0.0],
        texture_coords: [0.0, 0.0],
    },
    Vertex {
        position: [-1.0, -1.0, 0.0],
        texture_coords: [0.0, 1.0],
    },
];

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 2,
    2, 3, 0,
];

pub struct Common {
    pub _sampler: wgpu::Sampler,
    pub sampler_bind_group_layout: wgpu::BindGroupLayout,
    pub sampler_bind_group: wgpu::BindGroup,
    pub vertex_buffer: wgpu::Buffer,
    pub index_buffer: wgpu::Buffer,
}

impl Common {
    pub fn new(device: &wgpu::Device) -> Self {
        let vertex_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("edge rounder vertex buffer"),
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            contents: bytemuck::cast_slice(&VERTICES),
        });

        let index_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("edge rounder index buffer"),
            usage: wgpu::BufferUsages::INDEX | wgpu::BufferUsages::COPY_DST,
            contents: bytemuck::cast_slice(&INDICES),
        });

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("edge rounder sampler"),
            address_mode_u: wgpu::AddressMode::ClampToEdge,
            address_mode_w: wgpu::AddressMode::ClampToEdge,
            address_mode_v: wgpu::AddressMode::ClampToEdge,
            min_filter: wgpu::FilterMode::Nearest,
            mag_filter: wgpu::FilterMode::Nearest,
            mipmap_filter: wgpu::FilterMode::Nearest,
            ..Default::default()
        });

        let sampler_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("edge rounder sampler bind group layout"),
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                }],
            });

        let sampler_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("edge rounder sampler bind group"),
            layout: &sampler_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::Sampler(&sampler),
            }],
        });

        Self {
            _sampler: sampler,
            index_buffer,
            vertex_buffer,
            sampler_bind_group,
            sampler_bind_group_layout,
        }
    }
}