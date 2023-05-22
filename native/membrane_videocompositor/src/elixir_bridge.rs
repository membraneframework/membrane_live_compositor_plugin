use std::collections::HashMap;

use crate::compositor::math::Vec2d;
use crate::compositor::scene::Scene;
use crate::compositor::{self, VideoId};
use crate::elixir_bridge::elixir_structs::*;
use crate::errors::CompositorError;
use rustler::ResourceArc;

use self::elixir_scene::ElixirScene;

mod elixir_scene;
mod elixir_structs;

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum PixelFormat {
    I420,
}

impl TryFrom<rustler::Atom> for PixelFormat {
    type Error = CompositorError;

    fn try_from(value: rustler::Atom) -> Result<Self, Self::Error> {
        if value == atoms::I420() {
            Ok(PixelFormat::I420)
        } else {
            Err(CompositorError::UnsupportedPixelFormat)
        }
    }
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub struct RawVideo {
    pub width: std::num::NonZeroU32,
    pub height: std::num::NonZeroU32,
    pub pixel_format: PixelFormat,
    pub framerate: (std::num::NonZeroU64, std::num::NonZeroU64),
}

impl TryFrom<ElixirRawVideo> for RawVideo {
    type Error = CompositorError;

    fn try_from(value: ElixirRawVideo) -> Result<Self, Self::Error> {
        Ok(RawVideo {
            width: std::num::NonZeroU32::new(value.width).ok_or(
                CompositorError::BadVideoResolution(value.width, value.height),
            )?,
            height: std::num::NonZeroU32::new(value.height).ok_or(
                CompositorError::BadVideoResolution(value.width, value.height),
            )?,
            pixel_format: value.pixel_format.try_into()?,
            framerate: (
                std::num::NonZeroU64::new(value.framerate.0)
                    .ok_or(CompositorError::BadFramerate)?,
                std::num::NonZeroU64::new(value.framerate.1)
                    .ok_or(CompositorError::BadFramerate)?,
            ),
        })
    }
}

pub mod atoms {
    rustler::atoms! {
        ok,
        error,
        #[allow(non_snake_case)] I420,
        input_position,
        crop_part_position
    }
}

struct State(std::sync::Mutex<InnerState>);

impl State {
    fn new(output_stream_format: RawVideo) -> Result<Self, CompositorError> {
        Ok(Self(std::sync::Mutex::new(InnerState::new(
            output_stream_format,
        )?)))
    }
}

impl std::ops::Deref for State {
    type Target = std::sync::Mutex<InnerState>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

struct InnerState {
    compositor: compositor::State,
    output_stream_format: RawVideo,
}

impl InnerState {
    fn new(output_stream_format: RawVideo) -> Result<Self, CompositorError> {
        Ok(Self {
            compositor: pollster::block_on(compositor::State::new(&output_stream_format))?,
            output_stream_format,
        })
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn init(
    #[allow(unused)] env: rustler::Env,
    output_stream_format: ElixirRawVideo,
) -> Result<(rustler::Atom, rustler::ResourceArc<State>), rustler::Error> {
    let stream_format = output_stream_format.try_into()?;

    let result = std::thread::spawn(move || State::new(stream_format))
        .join()
        .expect("Couldn't join the thread responsible for initializing the compositor")?;

    Ok((atoms::ok(), rustler::ResourceArc::new(result)))
}

enum UploadFrameResult<'a> {
    WithoutFrame,
    WithFrame(rustler::Binary<'a>, u64),
}

impl rustler::Encoder for UploadFrameResult<'_> {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        match self {
            Self::WithoutFrame => atoms::ok().encode(env),
            Self::WithFrame(frame, pts) => (atoms::ok(), (frame.to_term(env), pts)).encode(env),
        }
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn process_frame<'a>(
    env: rustler::Env<'a>,
    state: ResourceArc<State>,
    id: usize,
    frame: rustler::Binary,
    pts: u64,
) -> Result<UploadFrameResult<'a>, rustler::Error> {
    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    state.compositor.upload_texture(id, &frame, pts)?;

    if state.compositor.all_frames_ready() {
        let (output, pts) = get_frame(&mut state);
        Ok(UploadFrameResult::WithFrame(output.release(env), pts))
    } else {
        Ok(UploadFrameResult::WithoutFrame)
    }
}

fn get_frame(state: &mut InnerState) -> (rustler::OwnedBinary, u64) {
    let mut output = rustler::OwnedBinary::new(
        state.output_stream_format.width.get() as usize
            * state.output_stream_format.height.get() as usize
            * 3
            / 2,
    )
    .unwrap(); //FIXME: return an error instead of panicking here

    let pts = pollster::block_on(state.compositor.draw_into(output.as_mut_slice()));

    (output, pts)
}

pub fn convert_z(z: f32) -> f32 {
    // we need to do this because 0.0 is an intuitively standard value and maps onto 1.0,
    // which is outside of the wgpu clip space
    1.0 - z.max(1e-7)
}

#[rustler::nif(schedule = "DirtyIo")]
fn set_videos(
    #[allow(unused)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    stream_format: HashMap<VideoId, ElixirRawVideo>,
    scene: ElixirScene,
) -> Result<rustler::Atom, rustler::Error> {
    let scene: Scene = scene.into();
    let mut videos_resolutions: HashMap<VideoId, Vec2d<u32>> = HashMap::new();

    for (video_id, video_format) in stream_format {
        videos_resolutions.insert(
            video_id,
            Vec2d {
                x: video_format.width,
                y: video_format.height,
            },
        );
    }

    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    state.compositor.set_videos(scene, videos_resolutions)?;

    Ok(atoms::ok())
}

rustler::init!(
    "Elixir.Membrane.VideoCompositor.Wgpu.Native",
    [init, process_frame, set_videos],
    load = |env, _| {
        rustler::resource!(State, env);
        true
    }
);
