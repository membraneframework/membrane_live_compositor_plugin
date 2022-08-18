#![deny(unsafe_op_in_unsafe_fn)]
//! This crate is a video compositor implementation using OpenGL, intended for use with an Elixir package. 

extern crate khronos_egl as egl;

use glad_gles2::gl;
use rustler::ResourceArc;

pub mod framebuffers;
pub mod scene;
pub mod shaders;
pub mod textures;

#[allow(non_snake_case)]
mod atoms {
  rustler::atoms! {
    ok,
    error,
    test_atom,
    unsupported_pixel_format,
    I420,

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
#[module = "Membrane.VideoCompositor.OpenGL.Rust.RawVideo"]
struct RawVideo {
  width: usize,
  height: usize,
  pixel_format: rustler::Atom
}

/// Contains structs used for holding the state of the compositor.
/// The structures in this module are mostly intended to be stored in the BEAM and passed to calls in this library.
pub mod state {
  use crate::scene::Scene;

  /// Holds the state of the compositor -- EGL parameters necessary to make the OpenGL context current and the [Scene].
  pub struct State {
    display: usize,
    context: usize,
    scene: Scene
  }

  impl State {
    /// Bind the OpenGL context and produce a [BoundContext] instance.
    pub fn bind_context(&self) -> Result<BoundContext, egl::Error> {
      let display = unsafe { egl::Display::from_ptr(self.display as *mut std::ffi::c_void) };
      let context = unsafe { egl::Context::from_ptr(self.context as *mut std::ffi::c_void) };
      egl::API.make_current(display, None, None, Some(context))?;
      Ok(BoundContext { display, scene: &self.scene })
    }

    /// Create the [State] from the EGL parameters and the [Scene]
    pub fn new(display: egl::Display, context: egl::Context, scene: Scene) -> Self {
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
    pub scene: &'a Scene
  }

  impl<'a> Drop for BoundContext<'a> {
    fn drop(&mut self) {
      egl::API
        .make_current(self.display, None, None, None)
        .expect("Can't make context not current");
    }
  }
}
use state::{State, BoundContext};

#[doc(hidden)]
fn load(env: rustler::Env, _: rustler::Term) -> bool {
  rustler::resource!(State, env);
  true
}

#[rustler::nif]
/// Initialize the compositor. This function is intended to only be called by Elixir.
fn init(first_video: RawVideo, second_video: RawVideo, out_video: RawVideo) -> Result<(rustler::Atom, ResourceArc<State>), rustler::Error> {
  use crate::scene::Scene;
  use crate::shaders::ShaderProgram;

  if first_video.pixel_format != atoms::I420() || second_video.pixel_format != atoms::I420() || out_video.pixel_format != atoms::I420() {
    return Err(rustler::Error::Term(Box::new(atoms::unsupported_pixel_format())));
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

  egl.make_current(display, None, None, Some(context)).nif_err()?;

  gl::load(|name| {
    egl
      .get_proc_address(name)
      .expect("Can't find a GLES procedure") as *const std::ffi::c_void
  });

  unsafe { gl::ClearColor(0.0, 0.0, 0.0, 1.0) }

  let vertex_shader_code = include_str!("shaders/vertex.glsl");
  let fragment_shader_code = include_str!("shaders/fragment.glsl");

  let shader_program = ShaderProgram::new(vertex_shader_code, fragment_shader_code)?;
  let mut scene = Scene::new(out_video.width, out_video.height, shader_program);
  scene.add_video(
    scene::VideoPlacementTemplate {
      top_right: (1.0, 1.0),
      top_left: (-1.0, 1.0),
      bot_left: (-1.0, 0.0),
      bot_right: (1.0, 0.0),
      z_value: 0.0
    },
    first_video.width, second_video.height
  );

  scene.add_video(
    scene::VideoPlacementTemplate {
      top_right: (1.0, 0.0),
      top_left: (-1.0, 0.0),
      bot_left: (-1.0, -1.0),
      bot_right: (1.0, -1.0),
      z_value: 0.0
    },
    first_video.width, second_video.height
  );



  egl.make_current(display, None, None, None).nif_err()?;
  Ok((atoms::ok(), ResourceArc::new(State::new(display, context, scene))))
}

#[rustler::nif]
/// Join two frames passed as [binaries](rustler::Binary). This function is intended to only be called by Elixir.
fn join_frames<'a>(env: rustler::Env<'a>, state: rustler::ResourceArc<State>, upper: rustler::Binary, lower: rustler::Binary) -> Result<(rustler::Atom, rustler::Term<'a>), rustler::Error> {
  let ctx: BoundContext = state.bind_context().nif_err()?;
  // for some reason VS Code can't suggest stuff correctly until 
  // I forward all of this into a different function. It's inlined and thusly free
  join_frames_fwd(env, &ctx, upper, lower)
}

#[inline(always)]
#[doc(hidden)]
fn join_frames_fwd<'a>(env: rustler::Env<'a>, ctx: &BoundContext, upper: rustler::Binary, lower: rustler::Binary)  -> Result<(rustler::Atom, rustler::Term<'a>), rustler::Error> {
  ctx.scene.upload_texture(0, upper.as_slice());
  ctx.scene.upload_texture(1, lower.as_slice());

  let mut binary = rustler::OwnedBinary::new(ctx.scene.out_width() * ctx.scene.out_height() * 3 / 2).unwrap();
  ctx.scene.draw_into(binary.as_mut_slice());
  Ok((atoms::ok(), binary.release(env).to_term(env)))
}


trait ResultExt<T> {
  /// Convert `T` into a [Result] with a [rustler::Error].
  fn nif_err(self) -> Result<T, rustler::Error>;
}

impl<T> ResultExt<T> for Result<T, egl::Error> {
  fn nif_err(self) -> Result<T, rustler::Error> {
    use rustler::Error;
    match self {
      Ok(x) => Ok(x),
      Err(error) => match error {
        egl::Error::NotInitialized => Err(Error::Term(Box::new(atoms::egl_not_initialized()))),
        egl::Error::BadAccess => Err(Error::Term(Box::new(atoms::egl_bad_access()))),
        egl::Error::BadAlloc => Err(Error::Term(Box::new(atoms::egl_bad_alloc()))),
        egl::Error::BadAttribute => Err(Error::Term(Box::new(atoms::egl_bad_attribute()))),
        egl::Error::BadContext => Err(Error::Term(Box::new(atoms::egl_bad_context()))),
        egl::Error::BadConfig => Err(Error::Term(Box::new(atoms::egl_bad_config()))),
        egl::Error::BadCurrentSurface => {
          Err(Error::Term(Box::new(atoms::egl_bad_current_surface())))
        }
        egl::Error::BadDisplay => Err(Error::Term(Box::new(atoms::egl_bad_display()))),
        egl::Error::BadSurface => Err(Error::Term(Box::new(atoms::egl_bad_surface()))),
        egl::Error::BadMatch => Err(Error::Term(Box::new(atoms::egl_bad_match()))),
        egl::Error::BadParameter => Err(Error::Term(Box::new(atoms::egl_bad_parameter()))),
        egl::Error::BadNativePixmap => Err(Error::Term(Box::new(atoms::egl_bad_native_pixmap()))),
        egl::Error::BadNativeWindow => Err(Error::Term(Box::new(atoms::egl_bad_native_window()))),
        egl::Error::ContextLost => Err(Error::Term(Box::new(atoms::egl_context_lost()))),
      },
    }
  }
}

rustler::init!(
  "Elixir.Membrane.VideoCompositor.OpenGL.Rust",
  [init, join_frames],
  load = load
);
