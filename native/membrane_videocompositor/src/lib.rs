use elixir_structs::*;
use errors::CompositorError;
use rustler::ResourceArc;

mod compositor;
mod elixir_structs;
mod errors;

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

mod atoms {
    rustler::atoms! {
        ok,
        error,
        #[allow(non_snake_case)] I420,
    }
}

struct State(std::sync::Mutex<InnerState>);

impl State {
    fn new(output_caps: RawVideo) -> Result<Self, CompositorError> {
        Ok(Self(std::sync::Mutex::new(InnerState::new(output_caps)?)))
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
    output_caps: RawVideo,
}

impl InnerState {
    fn new(output_caps: RawVideo) -> Result<Self, CompositorError> {
        Ok(Self {
            compositor: pollster::block_on(compositor::State::new(&output_caps))?,
            output_caps,
        })
    }
}

#[rustler::nif]
fn init(
    #[allow(unused)] env: rustler::Env,
    output_caps: ElixirRawVideo,
) -> Result<(rustler::Atom, rustler::ResourceArc<State>), rustler::Error> {
    Ok((
        atoms::ok(),
        rustler::ResourceArc::new(State::new(output_caps.try_into()?)?),
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

#[rustler::nif]
fn upload_frame<'a>(
    env: rustler::Env<'a>,
    state: ResourceArc<State>,
    id: usize,
    frame: rustler::Binary,
    pts: u64,
) -> Result<UploadFrameResult<'a>, rustler::Error> {
    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    state.compositor.upload_texture(id, &frame, pts)?;

    if state.compositor.all_frames_ready() {
        let mut output = rustler::OwnedBinary::new(
            state.output_caps.width.get() as usize * state.output_caps.height.get() as usize * 3
                / 2,
        )
        .unwrap();
        let pts = pollster::block_on(state.compositor.draw_into(output.as_mut_slice()));
        Ok(UploadFrameResult::WithFrame(output.release(env), pts))
    } else {
        Ok(UploadFrameResult::WithoutFrame)
    }
}

#[rustler::nif]
fn force_render(
    env: rustler::Env<'_>,
    state: ResourceArc<State>,
) -> Result<(rustler::Atom, (rustler::Term<'_>, u64)), rustler::Error> {
    let mut state = state.lock().unwrap();

    let mut output = rustler::OwnedBinary::new(
        state.output_caps.width.get() as usize * state.output_caps.height.get() as usize * 3 / 2,
    )
    .unwrap(); //FIXME: return an error instead of panicking here

    let pts = pollster::block_on(state.compositor.draw_into(output.as_mut_slice()));

    Ok((atoms::ok(), (output.release(env).to_term(env), pts)))
}

#[rustler::nif]
fn put_video(
    #[allow(unused)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
    input_video: ElixirRawVideo,
    properties: VideoProperties,
) -> Result<rustler::Atom, rustler::Error> {
    let input_video: RawVideo = input_video.try_into()?;

    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    state.compositor.put_video(
        id,
        compositor::VideoProperties {
            top_left: compositor::Point {
                x: properties.x,
                y: properties.y,
            },
            width: input_video.width.get(),
            height: input_video.height.get(),
            // we need to do this because 0.0 is an intuitively standard value and maps onto 1.0,
            // which is outside of the wgpu clip space
            z: 1.0 - properties.z.max(1e-7),
            scale: properties.scale,
        },
    );
    Ok(atoms::ok())
}

#[rustler::nif]
fn remove_video(
    #[allow(unused)] env: rustler::Env<'_>,
    state: ResourceArc<State>,
    id: usize,
) -> Result<rustler::Atom, rustler::Error> {
    state.lock().unwrap().compositor.remove_video(id)?;
    Ok(atoms::ok())
}

#[rustler::nif]
fn send_end_of_stream(
    #[allow(unused)] env: rustler::Env<'_>,
    state: ResourceArc<State>,
    id: usize,
) -> Result<rustler::Atom, rustler::Error> {
    state.lock().unwrap().compositor.send_end_of_stream(id)?;

    Ok(atoms::ok())
}

rustler::init!(
    "Elixir.Membrane.VideoCompositor.Wgpu.Native",
    [
        init,
        force_render,
        put_video,
        remove_video,
        upload_frame,
        send_end_of_stream
    ],
    load = |env, _| {
        rustler::resource!(State, env);
        true
    }
);
