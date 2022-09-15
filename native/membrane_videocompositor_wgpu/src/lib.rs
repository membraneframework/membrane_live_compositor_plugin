use rustler::ResourceArc;

mod compositor;

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.RawVideo"]
pub struct RawVideo {
    pub width: usize,
    pub height: usize,
    pub pixel_format: rustler::Atom,
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

struct State(std::sync::Mutex<InnerState>);

impl State {
    fn new(upper_caps: RawVideo, lower_caps: RawVideo, output_caps: RawVideo) -> Self {
        Self(std::sync::Mutex::new(InnerState::new(
            upper_caps,
            lower_caps,
            output_caps,
        )))
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
    _upper_caps: RawVideo,
    _lower_caps: RawVideo,
    output_caps: RawVideo,
}

impl InnerState {
    fn new(upper_caps: RawVideo, lower_caps: RawVideo, output_caps: RawVideo) -> Self {
        Self {
            compositor: pollster::block_on(compositor::State::new(
                &upper_caps,
                &lower_caps,
                &output_caps,
            )),
            _upper_caps: upper_caps,
            _lower_caps: lower_caps,
            output_caps,
        }
    }
}

#[rustler::nif]
fn init(
    #[allow(unused)] env: rustler::Env,
    upper_caps: RawVideo,
    lower_caps: RawVideo,
    output_caps: RawVideo,
) -> Result<(rustler::Atom, rustler::ResourceArc<State>), rustler::Error> {
    Ok((
        atoms::ok(),
        rustler::ResourceArc::new(State::new(upper_caps, lower_caps, output_caps)),
    ))
}

#[rustler::nif]
fn join_frames<'a>(
    env: rustler::Env<'a>,
    state: ResourceArc<State>,
    upper: rustler::Binary,
    lower: rustler::Binary,
) -> Result<(rustler::Atom, rustler::Term<'a>), rustler::Error> {
    let state = state.lock().unwrap();

    let mut output =
        rustler::OwnedBinary::new(state.output_caps.width * state.output_caps.height * 3 / 2)
            .unwrap(); //FIXME: return an error instead of panicking here

    pollster::block_on(state.compositor.join_frames(
        upper.as_slice(),
        lower.as_slice(),
        output.as_mut_slice(),
    ));

    Ok((atoms::ok(), output.release(env).to_term(env)))
}

rustler::init!(
    "Elixir.Membrane.VideoCompositor.Implementations.Wgpu.Native",
    [init, join_frames],
    load = |env, _| {
        rustler::resource!(State, env);
        true
    }
);
