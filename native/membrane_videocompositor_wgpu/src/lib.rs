use rustler::ResourceArc;

mod compositor;
mod errors;

#[derive(Debug, rustler::NifStruct, Clone)]
#[module = "Membrane.VideoCompositor.Common.RawVideo"]
pub struct RawVideo {
    pub width: u32,
    pub height: u32,
    pub pixel_format: rustler::Atom,
    pub framerate: (u64, u64),
}

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Common.Position"]
struct Position {
    x: u32,
    y: u32,
    z: f32,
    scale_factor: f64,
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

struct State(std::sync::Mutex<InnerState>);

impl State {
    fn new(output_caps: RawVideo) -> Self {
        Self(std::sync::Mutex::new(InnerState::new(output_caps)))
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
    fn new(output_caps: RawVideo) -> Self {
        Self {
            compositor: pollster::block_on(compositor::State::new(&output_caps)),
            output_caps,
        }
    }
}

#[rustler::nif]
fn init(
    #[allow(unused)] env: rustler::Env,
    output_caps: RawVideo,
) -> Result<(rustler::Atom, rustler::ResourceArc<State>), rustler::Error> {
    Ok((
        atoms::ok(),
        rustler::ResourceArc::new(State::new(output_caps)),
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

    if state.compositor.all_frames_ready(
        state.output_caps.framerate.1 as f64 / state.output_caps.framerate.0 as f64,
    ) {
        let mut output = rustler::OwnedBinary::new(
            state.output_caps.width as usize * state.output_caps.height as usize * 3 / 2,
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
        state.output_caps.width as usize * state.output_caps.height as usize * 3 / 2,
    )
    .unwrap(); //FIXME: return an error instead of panicking here

    let pts = pollster::block_on(state.compositor.draw_into(output.as_mut_slice()));

    Ok((atoms::ok(), (output.release(env).to_term(env), pts)))
}

#[rustler::nif]
fn add_video(
    #[allow(unused)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
    input_video: RawVideo,
    position: Position,
) -> Result<rustler::Atom, rustler::Error> {
    let mut state: std::sync::MutexGuard<InnerState> = state.lock().unwrap();

    state.compositor.add_video(
        id,
        compositor::VideoPosition {
            top_left: compositor::Point {
                x: position.x,
                y: position.y,
            },
            width: input_video.width,
            height: input_video.height,
            z: position.z,
            scale: position.scale_factor,
        },
    );
    Ok(atoms::ok())
}

#[rustler::nif]
fn set_position(
    #[allow(unused_variables)] env: rustler::Env<'_>,
    _state: rustler::ResourceArc<State>,
    _id: usize,
    _position: Position,
) -> Result<rustler::Atom, rustler::Error> {
    Err(errors::CompositorError::NotImplemented.into())
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

rustler::init!(
    "Elixir.Membrane.VideoCompositor.Wgpu.Native",
    [
        init,
        force_render,
        add_video,
        remove_video,
        set_position,
        upload_frame
    ],
    load = |env, _| {
        rustler::resource!(State, env);
        true
    }
);
