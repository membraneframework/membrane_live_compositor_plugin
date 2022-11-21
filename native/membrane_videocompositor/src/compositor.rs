use std::{collections::BTreeMap, fmt::Display, sync::Arc};

mod colour_converters;
mod textures;
mod videos;

use textures::*;
use videos::*;

use crate::errors::CompositorError;
pub use videos::VideoProperties;

use self::colour_converters::{RGBAToYUVConverter, YUVToRGBAConverter};

#[derive(Debug, Clone, Copy)]
#[repr(C)]
/// A point in 2D space
pub struct Point<T> {
    pub x: T,
    pub y: T,
}

impl<T: Display> Display for Point<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "({}, {})", self.x, self.y)
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

struct Sampler {
    _sampler: wgpu::Sampler,
    bind_group: wgpu::BindGroup,
}

pub struct State {
    device: wgpu::Device,
    input_videos: BTreeMap<usize, InputVideo>,
    output_textures: OutputTextures,
    pipeline: wgpu::RenderPipeline,
    queue: wgpu::Queue,
    sampler: Sampler,
    single_texture_bind_group_layout: Arc<wgpu::BindGroupLayout>,
    all_yuv_textures_bind_group_layout: Arc<wgpu::BindGroupLayout>,
    yuv_to_rgba_converter: YUVToRGBAConverter,
    rgba_to_yuv_converter: RGBAToYUVConverter,
    output_caps: crate::RawVideo,
    last_pts: Option<u64>,
}

impl State {
    pub async fn new(output_caps: &crate::RawVideo) -> Result<State, CompositorError> {
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
            output_caps.width.get(),
            output_caps.height.get(),
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
            label: Some("pipeline layout"),
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
            depth_stencil: Some(wgpu::DepthStencilState {
                format: wgpu::TextureFormat::Depth32Float,
                depth_write_enabled: true,
                depth_compare: wgpu::CompareFunction::Less,
                stencil: wgpu::StencilState::default(),
                bias: wgpu::DepthBiasState::default(),
            }),
        });

        let yuv_to_rgba_converter =
            YUVToRGBAConverter::new(&device, &all_yuv_textures_bind_group_layout);
        let rgba_to_yuv_converter =
            RGBAToYUVConverter::new(&device, &single_texture_bind_group_layout);

        Ok(Self {
            device,
            input_videos,
            output_textures,
            pipeline,
            queue,
            sampler: Sampler {
                _sampler: sampler,
                bind_group: sampler_bind_group,
            },
            single_texture_bind_group_layout: Arc::new(single_texture_bind_group_layout),
            all_yuv_textures_bind_group_layout: Arc::new(all_yuv_textures_bind_group_layout),
            yuv_to_rgba_converter,
            rgba_to_yuv_converter,
            output_caps: *output_caps,
            last_pts: None,
        })
    }

    pub fn upload_texture(
        &mut self,
        idx: usize,
        frame: &[u8],
        pts: u64,
    ) -> Result<(), CompositorError> {
        self.input_videos
            .get_mut(&idx)
            .ok_or(CompositorError::BadVideoIndex(idx))?
            .upload_data(
                &self.device,
                &self.queue,
                &self.yuv_to_rgba_converter,
                frame,
                pts,
                self.last_pts,
            );
        Ok(())
    }

    pub fn all_frames_ready(&self) -> bool {
        self.input_videos
            .values()
            .all(|v| v.is_frame_ready(self.frame_interval()))
    }

    /// This returns the pts of the new frame
    pub async fn draw_into(&mut self, output_buffer: &mut [u8]) -> u64 {
        let interval = self.frame_interval();
        self.input_videos
            .values_mut()
            .for_each(|v| v.remove_stale_frames(interval));

        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("encoder"),
            });

        let mut pts = 0;
        let mut ended_video_ids = Vec::new();

        {
            let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("render pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &self.output_textures.rgba_texture.texture.view,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: true,
                    },
                    resolve_target: None,
                })],
                depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                    view: &self.output_textures.depth_texture.view,
                    depth_ops: Some(wgpu::Operations {
                        load: wgpu::LoadOp::Clear(1.0),
                        store: true,
                    }),
                    stencil_ops: None,
                }),
            });

            render_pass.set_pipeline(&self.pipeline);
            render_pass.set_bind_group(1, &self.sampler.bind_group, &[]);

            for (&id, video) in self.input_videos.iter_mut() {
                match video.draw(&self.queue, &mut render_pass, &self.output_caps) {
                    DrawResult::Rendered(new_pts) => pts = pts.max(new_pts),
                    DrawResult::NotRendered => {}
                    DrawResult::EndOfStream => ended_video_ids.push(id),
                }
            }
        }

        ended_video_ids.iter().for_each(|id| {
            self.input_videos.remove(id);
        });
        self.input_videos.values_mut().for_each(|v| v.pop_frame());

        self.queue.submit(Some(encoder.finish()));

        self.output_textures.transfer_content_to_buffers(
            &self.device,
            &self.queue,
            &self.rgba_to_yuv_converter,
        );

        self.output_textures
            .download(&self.device, output_buffer)
            .await;

        self.last_pts = Some(pts);

        pts
    }

    pub fn add_video(&mut self, idx: usize, properties: VideoProperties) {
        self.input_videos.insert(
            idx,
            InputVideo::new(
                &self.device,
                self.single_texture_bind_group_layout.clone(),
                &self.all_yuv_textures_bind_group_layout,
                properties,
            ),
        );
    }

    pub fn remove_video(&mut self, idx: usize) -> Result<(), CompositorError> {
        self.input_videos
            .remove(&idx)
            .ok_or(CompositorError::BadVideoIndex(idx))?;
        Ok(())
    }

    pub fn send_end_of_stream(&mut self, idx: usize) -> Result<(), CompositorError> {
        self.input_videos
            .get_mut(&idx)
            .ok_or(CompositorError::BadVideoIndex(idx))?
            .send_end_of_stream();
        Ok(())
    }

    /// This is in nanoseconds
    pub fn frame_time(&self) -> f64 {
        self.output_caps.framerate.1.get() as f64 / self.output_caps.framerate.0.get() as f64
            * 1_000_000_000.0
    }

    pub fn frame_interval(&self) -> Option<(u64, u64)> {
        self.last_pts.map(|start| {
            (
                start,
                (((start as f64 + self.frame_time()) / 1_000_000.0).ceil() * 1_000_000.0) as u64,
            )
        })
    }

    #[allow(unused)]
    pub fn dump_queue_state(&self) {
        println!("[rust compositor queue dump]");
        println!(
            "interval: {:?}, frame_time: {}",
            self.frame_interval(),
            self.frame_time()
        );
        for (key, val) in &self.input_videos {
            println!("vid {key} => front pts {:?}", val.front_pts());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::num::{NonZeroU32, NonZeroU64};

    impl Default for crate::RawVideo {
        fn default() -> Self {
            Self {
                width: NonZeroU32::new(2).unwrap(),
                height: NonZeroU32::new(2).unwrap(),
                pixel_format: crate::PixelFormat::I420,
                framerate: (NonZeroU64::new(1).unwrap(), NonZeroU64::new(1).unwrap()),
            }
        }
    }

    const FRAME: &[u8; 6] = &[0x30, 0x40, 0x30, 0x40, 0x80, 0xb0];

    fn setup_videos(n: usize) -> State {
        let caps = crate::RawVideo {
            width: NonZeroU32::new(2 * n as u32).unwrap(),
            height: NonZeroU32::new(2).unwrap(),
            ..Default::default()
        };

        let mut compositor = pollster::block_on(State::new(&caps)).unwrap();

        for i in 0..n {
            compositor.add_video(
                i,
                VideoProperties {
                    top_left: Point {
                        x: 2 * i as u32,
                        y: 0,
                    },
                    width: 2,
                    height: 2,
                    z: 0.5,
                    scale: 1.0,
                },
            );
        }

        compositor
    }

    #[test]
    fn ends_streams_on_eos() {
        let mut compositor = setup_videos(2);

        compositor.upload_texture(0, FRAME, 0).unwrap();
        compositor.upload_texture(1, FRAME, 0).unwrap();

        assert!(compositor.all_frames_ready());

        pollster::block_on(compositor.draw_into(&mut [0; 12]));

        compositor.send_end_of_stream(1).unwrap();
        compositor.upload_texture(0, FRAME, 500_000_000).unwrap();

        assert!(compositor.all_frames_ready());
    }

    #[test]
    fn is_ready_after_receiving_all_frames() {
        let mut compositor = setup_videos(3);

        compositor.upload_texture(0, FRAME, 0).unwrap();
        assert!(!compositor.all_frames_ready());

        compositor.upload_texture(1, FRAME, 0).unwrap();
        assert!(!compositor.all_frames_ready());

        compositor.upload_texture(2, FRAME, 0).unwrap();
        assert!(compositor.all_frames_ready());

        pollster::block_on(compositor.draw_into(&mut [0; 18]));

        assert!(!compositor.all_frames_ready());

        compositor.upload_texture(0, FRAME, 500_000_000).unwrap();
        assert!(!compositor.all_frames_ready());

        compositor.upload_texture(0, FRAME, 1_500_000_000).unwrap();
        assert!(!compositor.all_frames_ready());

        compositor.upload_texture(1, FRAME, 500_000_000).unwrap();
        assert!(!compositor.all_frames_ready());

        compositor.upload_texture(2, FRAME, 500_000_000).unwrap();
        assert!(compositor.all_frames_ready());
    }
}
