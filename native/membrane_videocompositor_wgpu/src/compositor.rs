use std::collections::BTreeMap;

mod color_converters;
mod textures;
mod videos;

use textures::*;
use videos::*;

use crate::errors::CompositorError;

use self::color_converters::{RGBAToYUVConverter, YUVToRGBAConverter};

/// A point in 2D space
pub struct Point(pub f32, pub f32);

/// Describes where a video should be located in the scene space.
/// All coordinates have to be in the range [-1, 1].
pub struct VideoPlacementTemplate {
    pub top_right: Point,
    pub top_left: Point,
    pub bot_left: Point,
    pub bot_right: Point,
    /// This value is supposed to be used for making some videos appear 'in front of' other videos.
    /// This is still WIP and may not work.
    pub z_value: f32, // don't really know if setting this will do anything.. I guess it shouldn't without a depth buffer? FIXME??
}

impl From<VideoPlacementTemplate> for [Vertex; 4] {
    fn from(template: VideoPlacementTemplate) -> Self {
        let VideoPlacementTemplate {
            top_right,
            top_left,
            bot_right,
            bot_left,
            ..
        } = template;

        [
            Vertex {
                position: [top_right.0, top_right.1, 0.0],
                texture_coords: [1.0, 0.0],
            },
            Vertex {
                position: [top_left.0, top_left.1, 0.0],
                texture_coords: [0.0, 0.0],
            },
            Vertex {
                position: [bot_left.0, bot_left.1, 0.0],
                texture_coords: [0.0, 1.0],
            },
            Vertex {
                position: [bot_right.0, bot_right.1, 0.0],
                texture_coords: [1.0, 1.0],
            },
        ]
    }
}

#[repr(C)]
#[derive(Debug, Clone, Copy, bytemuck::Pod, bytemuck::Zeroable)]
pub struct Vertex {
    pub position: [f32; 3],
    pub texture_coords: [f32; 2],
}

impl Vertex {
    const LAYOUT: wgpu::VertexBufferLayout<'static> = wgpu::VertexBufferLayout {
        array_stride: std::mem::size_of::<Vertex>() as u64,
        step_mode: wgpu::VertexStepMode::Vertex,
        attributes: &wgpu::vertex_attr_array![0 => Float32x3, 1 => Float32x2],
    };
}

pub struct State {
    device: wgpu::Device,
    input_videos: BTreeMap<usize, InputVideo>,
    output_textures: OutputTextures,
    pipeline: wgpu::RenderPipeline,
    queue: wgpu::Queue,
    _sampler: wgpu::Sampler,
    sampler_bind_group: wgpu::BindGroup,
    single_texture_bind_group_layout: wgpu::BindGroupLayout,
    all_yuv_textures_bind_group_layout: wgpu::BindGroupLayout,
    yuv_to_rgba_converter: YUVToRGBAConverter,
    rgba_to_yuv_converter: RGBAToYUVConverter,
}

impl State {
    pub async fn new(output_caps: &crate::RawVideo) -> State {
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

        let single_texture_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("single texture bind group layout"),
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

        let all_yuv_textures_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("yuv all textures bind group layout"),
                entries: &[
                    wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        ty: wgpu::BindingType::Texture {
                            sample_type: wgpu::TextureSampleType::Float { filterable: true },
                            view_dimension: wgpu::TextureViewDimension::D2,
                            multisampled: false,
                        },
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        count: None,
                    },
                    wgpu::BindGroupLayoutEntry {
                        binding: 1,
                        ty: wgpu::BindingType::Texture {
                            sample_type: wgpu::TextureSampleType::Float { filterable: true },
                            view_dimension: wgpu::TextureViewDimension::D2,
                            multisampled: false,
                        },
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        count: None,
                    },
                    wgpu::BindGroupLayoutEntry {
                        binding: 2,
                        ty: wgpu::BindingType::Texture {
                            sample_type: wgpu::TextureSampleType::Float { filterable: true },
                            view_dimension: wgpu::TextureViewDimension::D2,
                            multisampled: false,
                        },
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        count: None,
                    },
                ],
            });

        let input_videos = BTreeMap::new();

        let output_textures = OutputTextures::new(
            &device,
            output_caps.width as u32,
            output_caps.height as u32,
            &single_texture_bind_group_layout,
        );

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
            bind_group_layouts: &[
                &single_texture_bind_group_layout,
                &sampler_bind_group_layout,
            ],
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

        let yuv_to_rgba_converter =
            YUVToRGBAConverter::new(&device, &all_yuv_textures_bind_group_layout);
        let rgba_to_yuv_converter =
            RGBAToYUVConverter::new(&device, &single_texture_bind_group_layout);

        Self {
            device,
            input_videos,
            output_textures,
            pipeline,
            queue,
            _sampler: sampler,
            sampler_bind_group,
            single_texture_bind_group_layout,
            all_yuv_textures_bind_group_layout,
            yuv_to_rgba_converter,
            rgba_to_yuv_converter,
        }
    }

    pub fn upload_texture(&self, idx: usize, frame: &[u8]) -> Result<(), CompositorError> {
        self.input_videos
            .get(&idx)
            .ok_or(CompositorError::BadVideoIndex(idx))?
            .upload_data(
                &self.device,
                &self.queue,
                &self.yuv_to_rgba_converter,
                frame,
            );
        Ok(())
    }

    pub async fn draw_into(&self, output_buffer: &mut [u8]) {
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("encoder"),
            });

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("i dont know yet"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &self.output_textures.rgba_texture.texture.view,
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

            for video in self.input_videos.values() {
                video.draw(&mut render_pass)
            }
        }

        self.queue.submit(Some(encoder.finish()));

        self.output_textures.transfer_content_to_buffers(
            &self.device,
            &self.queue,
            &self.rgba_to_yuv_converter,
        );

        self.output_textures
            .download(&self.device, output_buffer)
            .await;
    }

    pub fn add_video(
        &mut self,
        idx: usize,
        placement: VideoPlacementTemplate,
        width: usize,
        height: usize,
    ) {
        self.input_videos.insert(
            idx,
            InputVideo::new(
                &self.device,
                width as u32,
                height as u32,
                &placement.into(),
                &self.single_texture_bind_group_layout,
                &self.all_yuv_textures_bind_group_layout,
            ),
        );
    }

    pub fn remove_video(&mut self, idx: usize) -> Result<(), CompositorError> {
        self.input_videos
            .remove(&idx)
            .ok_or(CompositorError::BadVideoIndex(idx))?;
        Ok(())
    }
}
