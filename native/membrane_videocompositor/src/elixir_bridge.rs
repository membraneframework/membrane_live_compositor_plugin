use crate::compositor;
use crate::compositor::math::Vec2d;
use crate::elixir_bridge::elixir_structs::*;
use crate::errors::CompositorError;
use rustler::ResourceArc;

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
    Ok((
        atoms::ok(),
        rustler::ResourceArc::new(State::new(output_stream_format.try_into()?)?),
    ))
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

#[rustler::nif(schedule = "DirtyIo")]
fn force_render(
    env: rustler::Env<'_>,
    state: ResourceArc<State>,
) -> Result<(rustler::Atom, (rustler::Term<'_>, u64)), rustler::Error> {
    let mut state = state.lock().unwrap();

    let (output, pts) = get_frame(&mut state);

    Ok((atoms::ok(), (output.release(env).to_term(env), pts)))
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

#[rustler::nif(schedule = "DirtyIo")]
fn add_video(
    #[allow(unused)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
    stream_format: ElixirRawVideo,
    placement: ElixirBaseVideoPlacement,
    transformations: ElixirVideoTransformations,
) -> Result<rustler::Atom, rustler::Error> {
    let stream_format: RawVideo = stream_format.try_into()?;

    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    let base_placement = placement.into();

    let base_properties = compositor::VideoProperties {
        input_resolution: Vec2d {
            x: stream_format.width.get(),
            y: stream_format.height.get(),
        },

        placement: base_placement,
    };

    let texture_transformations = transformations.into();

    state
        .compositor
        .add_video(id, base_properties, texture_transformations)?;

    Ok(atoms::ok())
}

pub fn convert_z(z: f32) -> f32 {
    // we need to do this because 0.0 is an intuitively standard value and maps onto 1.0,
    // which is outside of the wgpu clip space
    1.0 - z.max(1e-7)
}

#[rustler::nif(schedule = "DirtyIo")]
fn update_stream_format(
    #[allow(unused)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
    stream_format: ElixirRawVideo,
) -> Result<rustler::Atom, rustler::Error> {
    let stream_format: RawVideo = stream_format.try_into()?;
    let stream_format = Vec2d {
        x: stream_format.width.get(),
        y: stream_format.height.get(),
    };

    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    state
        .compositor
        .update_properties(id, Some(stream_format), None, None)?;

    Ok(atoms::ok())
}

#[rustler::nif(schedule = "DirtyIo")]
fn update_placement(
    #[allow(unused)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
    placement: ElixirBaseVideoPlacement,
) -> Result<rustler::Atom, rustler::Error> {
    let placement = placement.into();

    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    state
        .compositor
        .update_properties(id, None, Some(placement), None)?;

    Ok(atoms::ok())
}

#[rustler::nif(schedule = "DirtyIo")]
fn update_transformations(
    #[allow(unused)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
    transformations: ElixirVideoTransformations,
) -> Result<rustler::Atom, rustler::Error> {
    let texture_transformations = transformations.into();

    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    state
        .compositor
        .update_properties(id, None, None, Some(texture_transformations))?;

    Ok(atoms::ok())
}

#[rustler::nif(schedule = "DirtyIo")]
fn remove_video(
    #[allow(unused)] env: rustler::Env<'_>,
    state: ResourceArc<State>,
    id: usize,
) -> Result<rustler::Atom, rustler::Error> {
    state.lock().unwrap().compositor.remove_video(id)?;
    Ok(atoms::ok())
}

#[rustler::nif(schedule = "DirtyIo")]
fn send_end_of_stream(
    #[allow(unused)] env: rustler::Env<'_>,
    state: ResourceArc<State>,
    id: usize,
) -> Result<(rustler::Atom, Vec<(rustler::Term<'_>, u64)>), rustler::Error> {
    let mut state = state.lock().unwrap();

    state.compositor.send_end_of_stream(id)?;

    let mut outputs = Vec::new();

    while state.compositor.all_frames_ready() {
        let (output, pts) = get_frame(&mut state);
        let output = output.release(env).to_term(env);
        outputs.push((output, pts))
    }

    Ok((atoms::ok(), outputs))
}

rustler::init!(
    "Elixir.Membrane.VideoCompositor.Wgpu.Native",
    [
        init,
        force_render,
        add_video,
        remove_video,
        process_frame,
        send_end_of_stream,
        update_stream_format,
        update_placement,
        update_transformations
    ],
    load = |env, _| {
        rustler::resource!(State, env);
        true
    }
);
