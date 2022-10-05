use rustler::ResourceArc;

mod compositor;
mod errors;

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.RawVideo"]
pub struct RawVideo {
    pub width: u32,
    pub height: u32,
    pub pixel_format: rustler::Atom,
}

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.Position"]
struct Position {
    x: usize,
    y: usize,
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

#[rustler::nif]
fn join_frames<'a>(
    env: rustler::Env<'a>,
    state: ResourceArc<State>,
    frames: Vec<(usize, rustler::Binary)>,
) -> Result<(rustler::Atom, rustler::Term<'a>), rustler::Error> {
    let state = state.lock().unwrap();

    for (i, frame) in &frames {
        state.compositor.upload_texture(*i, frame)?
    }

    let mut output = rustler::OwnedBinary::new(
        state.output_caps.width as usize * state.output_caps.height as usize * 3 / 2,
    )
    .unwrap(); //FIXME: return an error instead of panicking here

    pollster::block_on(state.compositor.draw_into(output.as_mut_slice()));

    Ok((atoms::ok(), output.release(env).to_term(env)))
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
    let placement = determine_video_placement(&state, &input_video, &position);

    state.compositor.add_video(
        id,
        placement,
        input_video.width as usize,
        input_video.height as usize,
    );
    Ok(atoms::ok())
}

/// Maps point `x` from the domain \[`x_min`, `x_max`\] to the point in the \[`y_min, y_max`\] line segment, using linear interpolation.
///
/// `x` outside the original domain will be extrapolated outside the targe domain.
fn lerp(x: f64, x_min: f64, x_max: f64, y_min: f64, y_max: f64) -> f64 {
    (x - x_min) / (x_max - x_min) * (y_max - y_min) + y_min
}

fn determine_video_placement(
    state: &InnerState,
    input_video: &RawVideo,
    position: &Position,
) -> compositor::VideoPlacementTemplate {
    let scene_width = state.output_caps.width;
    let scene_height = state.output_caps.height;

    let left = lerp(position.x as f64, 0.0, scene_width as f64, -1.0, 1.0) as f32;
    let right = lerp(
        (position.x + input_video.width as usize) as f64,
        0.0,
        scene_width as f64,
        -1.0,
        1.0,
    ) as f32;
    let top = lerp(position.y as f64, 0.0, scene_height as f64, 1.0, -1.0) as f32;
    let bot = lerp(
        (position.y + input_video.height as usize) as f64,
        0.0,
        scene_height as f64,
        1.0,
        -1.0,
    ) as f32;

    compositor::VideoPlacementTemplate {
        top_right: compositor::Point(right, top),
        top_left: compositor::Point(left, top),
        bot_left: compositor::Point(left, bot),
        bot_right: compositor::Point(right, bot),
        z_value: 0.0,
    }
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
    "Elixir.Membrane.VideoCompositor.Implementations.Wgpu.Native",
    [init, join_frames, add_video, remove_video, set_position],
    load = |env, _| {
        rustler::resource!(State, env);
        true
    }
);
