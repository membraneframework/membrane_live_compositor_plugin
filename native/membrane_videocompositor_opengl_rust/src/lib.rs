#![deny(unsafe_op_in_unsafe_fn)]
//! This crate is a video compositor implementation using OpenGL, intended for use with an Elixir package.

extern crate khronos_egl as egl;

use rustler::ResourceArc;

pub mod errors;
pub mod framebuffers;
pub mod scene;
pub mod shaders;
pub mod textures;

macro_rules! gl {
    ($call:expr) => {{
        // FIXME: we should probably add something like `ensure_current_thread_holds_context` here
        let result = $call;
        crate::errors::result_or_gl_error(result, file!(), line!(), stringify!(call))
    }};
}

pub(crate) use gl;

#[allow(non_snake_case)]
mod atoms {
    rustler::atoms! {
      ok,
      error,
      test_atom,
      unsupported_pixel_format,
      I420,
      function_not_implemented,

      egl_not_initialized,
      egl_bad_access,
      egl_bad_alloc,
      egl_bad_attribute,
      egl_bad_context,
      egl_bad_config,
      egl_bad_current_surface,
      egl_bad_display,
      egl_bad_surface,
      egl_bad_match,
      egl_bad_parameter,
      egl_bad_native_pixmap,
      egl_bad_native_window,
      egl_context_lost,
    }
}

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.RawVideo"]
struct RawVideo {
    height: usize,
    width: usize,
    pixel_format: rustler::Atom,
}

/// Position relative to the top right corner of the viewport, in pixels
#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust.Position"]
struct Position {
    x: usize,
    y: usize,
}

/// Contains structs used for holding the state of the compositor.
/// The structures in this module are mostly intended to be stored in the BEAM and passed to calls in this library.
pub mod state {
    use std::{ops::Deref, sync::Mutex};

    use crate::scene::Scene;

    /// Holds the state of the compositor -- EGL parameters necessary to make the OpenGL context current and the [Scene].
    pub struct State {
        inner: Mutex<InnerState>,
    }

    impl State {
        pub fn new(display: egl::Display, context: egl::Context, scene: Scene) -> Self {
            Self {
                inner: Mutex::new(InnerState::new(display, context, scene)),
            }
        }
    }

    impl Deref for State {
        type Target = Mutex<InnerState>;

        fn deref(&self) -> &Self::Target {
            &self.inner
        }
    }

    pub struct InnerState {
        display: usize,
        context: usize,
        scene: Scene,
    }

    impl InnerState {
        /// Bind the OpenGL context and produce a [BoundContext] instance.
        pub fn bind_context(&mut self) -> Result<BoundContext, egl::Error> {
            let display = unsafe { egl::Display::from_ptr(self.display as *mut std::ffi::c_void) };
            let context = unsafe { egl::Context::from_ptr(self.context as *mut std::ffi::c_void) };
            egl::API.make_current(display, None, None, Some(context))?;
            Ok(BoundContext {
                display,
                scene: &mut self.scene,
            })
        }

        /// Create the [State] from the EGL parameters and the [Scene]
        fn new(display: egl::Display, context: egl::Context, scene: Scene) -> Self {
            Self {
                display: display.as_ptr() as usize,
                context: context.as_ptr() as usize,
                scene,
            }
        }
    }

    /// A proof that the current thread has made an OpenGL context current.
    /// It releases the context automatically when dropped. It's necessary to create this struct (using [State::bind_context]) in order to access the [Scene].
    pub struct BoundContext<'a> {
        display: egl::Display,
        pub scene: &'a mut Scene,
    }

    impl<'a> Drop for BoundContext<'a> {
        fn drop(&mut self) {
            egl::API
                .make_current(self.display, None, None, None)
                .expect("Can't make context not current");
        }
    }
}
use state::{BoundContext, State};

use crate::scene::Point;

#[doc(hidden)]
fn load(env: rustler::Env, _: rustler::Term) -> bool {
    rustler::resource!(State, env);
    true
}

#[rustler::nif]
/// Initialize the compositor. This function is intended to only be called by Elixir.
fn init(out_video: RawVideo) -> Result<(rustler::Atom, ResourceArc<State>), rustler::Error> {
    use crate::scene::Scene;
    use crate::shaders::ShaderProgram;

    if out_video.pixel_format != atoms::I420() {
        return Err(rustler::Error::Term(Box::new(
            atoms::unsupported_pixel_format(),
        )));
    }

    let egl = &egl::API;

    let display = egl
        .get_display(egl::DEFAULT_DISPLAY)
        .ok_or(rustler::Error::Atom("cant_get_default_display"))?;

    egl.initialize(display).nif_err()?;

    #[rustfmt::skip]
    let attributes = [
        egl::SURFACE_TYPE,  egl::PBUFFER_BIT,
        egl::RED_SIZE,      8,
        egl::GREEN_SIZE,    8,
        egl::BLUE_SIZE,     8,
        egl::CONFORMANT,    egl::OPENGL_ES3_BIT,
        egl::NONE
    ];

    let config = egl
        .choose_first_config(display, &attributes)
        .nif_err()?
        .expect("Got no compatible config");

    #[rustfmt::skip]
    let attributes = [
        egl::CONTEXT_MAJOR_VERSION, 3,
        egl::CONTEXT_MINOR_VERSION, 0,
        egl::NONE,
    ];

    let context = egl
        .create_context(display, config, None, &attributes)
        .nif_err()?;

    egl.make_current(display, None, None, Some(context))
        .nif_err()?;

    glad_gles2::gl::load(|name| {
        egl.get_proc_address(name)
            .expect("Can't find a GLES procedure") as *const std::ffi::c_void
    });

    unsafe { gl!(glad_gles2::gl::ClearColor(0.0, 0.0, 0.0, 1.0))? }

    let vertex_shader_code = include_str!("shaders/vertex.glsl");
    let fragment_shader_code = include_str!("shaders/fragment.glsl");

    let shader_program = ShaderProgram::new(vertex_shader_code, fragment_shader_code)?;
    let scene = Scene::new(out_video.width, out_video.height, shader_program)?;

    egl.make_current(display, None, None, None).nif_err()?;
    Ok((
        atoms::ok(),
        ResourceArc::new(State::new(display, context, scene)),
    ))
}

#[rustler::nif]
fn add_video(
    #[allow(unused_variables)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
    input_video: RawVideo,
    position: Position,
) -> Result<rustler::Atom, rustler::Error> {
    let mut locked = state.lock().unwrap();
    let mut ctx = locked.bind_context().nif_err()?;

    add_video_fwd(&mut ctx, id, input_video, position)
}

#[inline(always)]
#[doc(hidden)]
fn add_video_fwd(
    ctx: &mut BoundContext,
    id: usize,
    input_video: RawVideo,
    position: Position,
) -> Result<rustler::Atom, rustler::Error> {
    ctx.scene.add_video(
        id,
        determine_video_placement(ctx.scene, &input_video, &position),
        input_video.width,
        input_video.height,
    )?;

    Ok(atoms::ok())
}

/// Maps point `x` from the domain \[`x_min`, `x_max`\] to the point in the \[`y_min, y_max`\] line segment, using linear interpolation.
///
/// `x` outside the original domain will be extrapolated outside the targe domain.
fn lerp(x: f64, x_min: f64, x_max: f64, y_min: f64, y_max: f64) -> f64 {
    (x - x_min) / (x_max - x_min) * (y_max - y_min) + y_min
}

fn determine_video_placement(
    scene: &scene::Scene,
    input_video: &RawVideo,
    position: &Position,
) -> scene::VideoPlacementTemplate {
    let scene_width = scene.out_width();
    let scene_height = scene.out_height();

    let left = lerp(position.x as f64, 0.0, scene_width as f64, -1.0, 1.0) as f32;
    let right = lerp(
        (position.x + input_video.width) as f64,
        0.0,
        scene_width as f64,
        -1.0,
        1.0,
    ) as f32;
    let top = lerp(position.y as f64, 0.0, scene_height as f64, 1.0, -1.0) as f32;
    let bot = lerp(
        (position.y + input_video.height) as f64,
        0.0,
        scene_height as f64,
        1.0,
        -1.0,
    ) as f32;

    scene::VideoPlacementTemplate {
        top_right: Point(right, top),
        top_left: Point(left, top),
        bot_left: Point(left, bot),
        bot_right: Point(right, bot),
        z_value: 0.0,
    }
}

#[rustler::nif]
fn remove_video(
    #[allow(unused_variables)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
) -> Result<rustler::Atom, rustler::Error> {
    let mut locked = state.lock().unwrap();
    let mut ctx = locked.bind_context().nif_err()?;

    remove_video_fwd(&mut ctx, id)
}

#[inline(always)]
#[doc(hidden)]
fn remove_video_fwd(ctx: &mut BoundContext, id: usize) -> Result<rustler::Atom, rustler::Error> {
    ctx.scene.remove_video(id)?;
    Ok(atoms::ok())
}

#[rustler::nif]
fn set_position(
    #[allow(unused_variables)] env: rustler::Env<'_>,
    state: rustler::ResourceArc<State>,
    id: usize,
    position: Position,
) -> Result<rustler::Atom, rustler::Error> {
    let mut locked = state.lock().unwrap();
    let mut ctx = locked.bind_context().nif_err()?;

    set_position_fwd(&mut ctx, id, position)
}

#[inline(always)]
#[doc(hidden)]
fn set_position_fwd(
    _ctx: &mut BoundContext,
    _id: usize,
    _position: Position,
) -> Result<rustler::Atom, rustler::Error> {
    Err(rustler::Error::Term(Box::new(
        atoms::function_not_implemented(),
    )))
}

#[rustler::nif]
/// Join two frames passed as [binaries](rustler::Binary). This function is intended to only be called by Elixir.
fn join_frames<'a>(
    env: rustler::Env<'a>,
    state: rustler::ResourceArc<State>,
    input_videos: Vec<(usize, rustler::Binary)>,
) -> Result<(rustler::Atom, rustler::Term<'a>), rustler::Error> {
    let mut locked = state.lock().unwrap();
    let mut ctx = locked.bind_context().nif_err()?;
    // for some reason VS Code can't suggest stuff correctly until
    // I forward all of this into a different function. It's inlined and thusly free
    join_frames_fwd(env, &mut ctx, input_videos)
}

#[inline(always)]
#[doc(hidden)]
fn join_frames_fwd<'a>(
    env: rustler::Env<'a>,
    ctx: &mut BoundContext,
    input_videos: Vec<(usize, rustler::Binary)>,
) -> Result<(rustler::Atom, rustler::Term<'a>), rustler::Error> {
    for (i, video) in &input_videos {
        ctx.scene.upload_texture(*i, video.as_slice())?;
    }

    let mut binary =
        rustler::OwnedBinary::new(ctx.scene.out_width() * ctx.scene.out_height() * 3 / 2).unwrap();
    ctx.scene.draw_into(binary.as_mut_slice())?;
    Ok((atoms::ok(), binary.release(env).to_term(env)))
}

trait ResultExt<T> {
    /// Convert `T` into a [Result] with a [rustler::Error].
    fn nif_err(self) -> Result<T, rustler::Error>;
}

impl<T> ResultExt<T> for Result<T, egl::Error> {
    fn nif_err(self) -> Result<T, rustler::Error> {
        use rustler::Error;
        self.map_err(|error| match error {
            egl::Error::NotInitialized => Error::Term(Box::new(atoms::egl_not_initialized())),
            egl::Error::BadAccess => Error::Term(Box::new(atoms::egl_bad_access())),
            egl::Error::BadAlloc => Error::Term(Box::new(atoms::egl_bad_alloc())),
            egl::Error::BadAttribute => Error::Term(Box::new(atoms::egl_bad_attribute())),
            egl::Error::BadContext => Error::Term(Box::new(atoms::egl_bad_context())),
            egl::Error::BadConfig => Error::Term(Box::new(atoms::egl_bad_config())),
            egl::Error::BadCurrentSurface => {
                Error::Term(Box::new(atoms::egl_bad_current_surface()))
            }
            egl::Error::BadDisplay => Error::Term(Box::new(atoms::egl_bad_display())),
            egl::Error::BadSurface => Error::Term(Box::new(atoms::egl_bad_surface())),
            egl::Error::BadMatch => Error::Term(Box::new(atoms::egl_bad_match())),
            egl::Error::BadParameter => Error::Term(Box::new(atoms::egl_bad_parameter())),
            egl::Error::BadNativePixmap => Error::Term(Box::new(atoms::egl_bad_native_pixmap())),
            egl::Error::BadNativeWindow => Error::Term(Box::new(atoms::egl_bad_native_window())),
            egl::Error::ContextLost => Error::Term(Box::new(atoms::egl_context_lost())),
        })
    }
}

rustler::init!(
    "Elixir.Membrane.VideoCompositor.Implementations.OpenGL.Native.Rust",
    [init, join_frames, add_video, remove_video, set_position],
    load = load
);
