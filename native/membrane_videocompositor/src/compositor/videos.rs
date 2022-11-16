use std::collections::VecDeque;
use std::sync::Arc;

use wgpu::util::DeviceExt;

use super::colour_converters::YUVToRGBAConverter;
use super::textures::{RGBATexture, YUVTextures};
use super::{Point, Vertex};

#[derive(Debug, Clone, Copy)]
// All of the fields are in pixels, except of the `z`, which should be from the <0, 1> range
pub struct VideoProperties {
    /// Position in pixels.
    /// Specifying a position outside of the `output_caps`
    /// of the scene this will be rendered onto will cause it to not be displayed.
    pub top_left: Point<u32>,
    pub width: u32,
    pub height: u32,
    pub z: f32,
    pub scale: f64,
}

pub enum Message {
    Frame { pts: u64, frame: RGBATexture },
    EndOfStream,
}

pub enum DrawResult {
    /// Contains the pts of the rendered frame
    Rendered(u64),
    NotRendered,
    EndOfStream,
}

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 3,
    1, 2, 3
];

pub struct InputVideo {
    frames: VecDeque<Message>,
    yuv_textures: YUVTextures,
    vertices: wgpu::Buffer,
    indices: wgpu::Buffer,
    properties: VideoProperties,
    previous_frame: Option<Message>,
    single_texture_bind_group_layout: Arc<wgpu::BindGroupLayout>,
}

impl InputVideo {
    pub fn new(
        device: &wgpu::Device,
        single_texture_bind_group_layout: Arc<wgpu::BindGroupLayout>,
        all_textures_bind_group_layout: &wgpu::BindGroupLayout,
        properties: VideoProperties,
    ) -> Self {
        let yuv_textures = YUVTextures::new(
            device,
            properties.width,
            properties.height,
            wgpu::TextureUsages::COPY_DST | wgpu::TextureUsages::TEXTURE_BINDING,
            Some(&single_texture_bind_group_layout),
            Some(all_textures_bind_group_layout),
        );

        let frames = VecDeque::new();

        let vertices = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("video vertex buffer"),
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            size: std::mem::size_of::<Vertex>() as u64 * 4,
            mapped_at_creation: false,
        });

        let indices = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("video index buffer"),
            contents: bytemuck::cast_slice(&INDICES),
            usage: wgpu::BufferUsages::INDEX,
        });

        Self {
            yuv_textures,
            frames,
            vertices,
            indices,
            properties,
            previous_frame: None,
            single_texture_bind_group_layout,
        }
    }

    pub fn upload_data(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        converter: &YUVToRGBAConverter,
        data: &[u8],
        pts: u64,
        last_rendered_pts: Option<u64>,
    ) {
        self.yuv_textures.upload_data(queue, data);
        let frame = RGBATexture::new(
            device,
            self.properties.width,
            self.properties.height,
            &self.single_texture_bind_group_layout,
        );
        converter.convert(device, queue, &self.yuv_textures, &frame);

        // if we haven't rendered a frame yet, or pts of our frame is ahead of last rendered frame
        if last_rendered_pts.is_none() || pts > last_rendered_pts.unwrap() {
            // then we can add the frame to the queue (we assume the frames come in order)
            self.frames.push_back(Message::Frame { frame, pts });
        }
        // otherwise, our frame is too old to be added to the queue, so we check if it is newer than the previously used frame,
        // which is our fallback in case we are forced to render before a new enough frame arrives.
        else if let Some(Message::Frame { pts: prev_pts, .. }) = self.previous_frame.as_ref() {
            if *prev_pts < pts {
                self.previous_frame = Some(Message::Frame { frame, pts });
            }
        }
    }

    pub fn vertex_data(&self, output_caps: &crate::RawVideo) -> [Vertex; 4] {
        let scene_width = output_caps.width;
        let scene_height = output_caps.height;

        let position = self.properties.top_left;
        let width = self.properties.width;
        let height = self.properties.height;

        let left = lerp(
            self.properties.top_left.x as f64,
            0.0,
            scene_width.get() as f64,
            -1.0,
            1.0,
        ) as f32;
        let right = lerp(
            position.x as f64 + width as f64 * self.properties.scale,
            0.0,
            scene_width.get() as f64,
            -1.0,
            1.0,
        ) as f32;
        let top = lerp(position.y as f64, 0.0, scene_height.get() as f64, 1.0, -1.0) as f32;
        let bot = lerp(
            position.y as f64 + height as f64 * self.properties.scale,
            0.0,
            scene_height.get() as f64,
            1.0,
            -1.0,
        ) as f32;

        [
            Vertex {
                position: [right, top, self.properties.z],
                texture_coords: [1.0, 0.0],
            },
            Vertex {
                position: [left, top, self.properties.z],
                texture_coords: [0.0, 0.0],
            },
            Vertex {
                position: [left, bot, self.properties.z],
                texture_coords: [0.0, 1.0],
            },
            Vertex {
                position: [right, bot, self.properties.z],
                texture_coords: [1.0, 1.0],
            },
        ]
    }

    pub fn front_pts(&self) -> Option<u64> {
        if let Some(Message::Frame { pts, .. }) = self.frames.front() {
            Some(*pts)
        } else {
            None
        }
    }

    /// This returns pts of the used frame
    pub fn draw<'a>(
        &'a mut self,
        queue: &wgpu::Queue,
        render_pass: &mut wgpu::RenderPass<'a>,
        output_caps: &crate::RawVideo,
    ) -> DrawResult {
        queue.write_buffer(
            &self.vertices,
            0,
            bytemuck::cast_slice(&self.vertex_data(output_caps)),
        );

        let (frame, pts) = match self.frames.front() {
            Some(Message::Frame { frame, pts }) => (frame, *pts),

            Some(Message::EndOfStream) => return DrawResult::EndOfStream,

            None => match self.previous_frame.as_ref() {
                Some(Message::Frame { pts, frame }) => (frame, *pts),

                Some(Message::EndOfStream) => return DrawResult::EndOfStream,

                None => return DrawResult::NotRendered,
            },
        };

        render_pass.set_bind_group(0, frame.texture.bind_group.as_ref().unwrap(), &[]);

        render_pass.set_index_buffer(self.indices.slice(..), wgpu::IndexFormat::Uint16);
        render_pass.set_vertex_buffer(0, self.vertices.slice(..));

        let indices_len = (self.indices.size() / std::mem::size_of::<u16>() as u64) as u32;

        render_pass.draw_indexed(0..indices_len, 0, 0..1);

        DrawResult::Rendered(pts)
    }

    pub fn remove_stale_frames(&mut self, interval: Option<(u64, u64)>) {
        while self.is_front_frame_too_old(interval) {
            self.pop_frame();
        }
    }

    pub fn pop_frame(&mut self) {
        if let Some(Message::Frame { pts, frame }) = self.frames.pop_front() {
            self.previous_frame = Some(Message::Frame { pts, frame });
        }
    }

    pub fn send_end_of_stream(&mut self) {
        self.frames.push_back(Message::EndOfStream);
    }

    pub fn is_front_frame_too_old(&self, interval: Option<(u64, u64)>) -> bool {
        if let Some(Message::EndOfStream) = self.frames.front() {
            return false;
        }

        if interval.is_none() || self.front_pts().is_none() {
            return false;
        }

        self.front_pts().is_some() && interval.unwrap().0 > self.front_pts().unwrap()
    }

    pub fn is_frame_ready(&self, interval: Option<(u64, u64)>) -> bool {
        if let Some(Message::EndOfStream) = self.frames.front() {
            return true;
        }

        self.front_pts().is_some() // if the stream hasn't ended then we have to have a frame in the queue, then either:
            && (interval.is_none() // this is the first frame, which means a frame with any pts is good
                || (interval.unwrap().0 <= self.front_pts().unwrap()
                    && self.front_pts().unwrap() <= interval.unwrap().1)) // or we have to fit between the start and end pts
    }
}

/// Maps point `x` from the domain \[`x_min`, `x_max`\] to the point in the \[`y_min, y_max`\] line segment, using linear interpolation.
///
/// `x` outside the original domain will be extrapolated outside the target domain.
fn lerp(x: f64, x_min: f64, x_max: f64, y_min: f64, y_max: f64) -> f64 {
    (x - x_min) / (x_max - x_min) * (y_max - y_min) + y_min
}
