#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.OpenGL.Implementations.Native.Rust.RawVideo"]
struct RawVideo {
    width: usize,
    height: usize,
    pixel_format: rustler::Atom,
}

struct State(std::sync::Mutex<InnerState>);

impl std::ops::Deref for State {
    type Target = std::sync::Mutex<InnerState>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

struct InnerState {}

#[doc(hidden)]
fn load(env: rustler::Env, _: rustler::Term) -> bool {
    rustler::resource!(State, env);
    true
}

#[rustler::nif]
fn init(
    _first_video: RawVideo,
    _second_video: RawVideo,
    _out_video: RawVideo,
) -> Result<(rustler::Atom, rustler::ResourceArc<State>), rustler::Error> {
    todo!()
}

#[rustler::nif]
fn join_frames<'a>(
    #[allow(unused)] env: rustler::Env<'a>,
    _state: rustler::ResourceArc<State>,
    _upper: rustler::Binary,
    _lower: rustler::Binary,
) -> Result<(rustler::Atom, rustler::Term<'a>), rustler::Error> {
    todo!()
}

rustler::init!(
    "Elixir.Membrane.VideoCompositor.Implementations.Wgpu.Native",
    [init, join_frames],
    load = load
);
