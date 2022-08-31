use thiserror::Error;

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.OpenGL.Rust.ErrorLocation"]
/// Carries information about a location where an error happened
pub struct ErrorLocation {
    file: String,
    line: u32,
    call: String,
}

pub fn result_or_gl_error<T>(
    res: T,
    file: &str,
    line: u32,
    call: &str,
) -> Result<T, CompositorError> {
    use glad_gles2::gl;

    let err = unsafe { gl::GetError() };

    if err == gl::NO_ERROR {
        return Ok(res);
    }

    let location = ErrorLocation {
        file: file.to_string(),
        line,
        call: call.to_string(),
    };

    match err {
        gl::INVALID_ENUM => Err(CompositorError::GLError("gl_invalid_enum", location)),
        gl::INVALID_VALUE => Err(CompositorError::GLError("gl_invalid_value", location)),
        gl::INVALID_OPERATION => Err(CompositorError::GLError("gl_invalid_operation", location)),
        gl::INVALID_FRAMEBUFFER_OPERATION => Err(CompositorError::GLError(
            "gl_invalid_framebuffer_operations",
            location,
        )),
        gl::OUT_OF_MEMORY => Err(CompositorError::GLError("gl_out_of_memory", location)),
        _ => panic!(
            "Error code grabbed from glGetError is not an OpenGL error code (it is {:#x})",
            err
        ),
    }
}

mod atoms {
    rustler::atoms! {
        error,
    }
}

#[derive(Debug, Error)]
/// An enum representing various errors that can happen during composition
pub enum CompositorError {
    #[error("shader compilation or linking error")]
    ShaderError(&'static str),
    #[error("error while calling OpenGL")]
    GLError(&'static str, ErrorLocation),
}

impl rustler::Encoder for CompositorError {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        match self {
            CompositorError::ShaderError(atom) => {
                rustler::Atom::from_str(env, atom).unwrap().encode(env)
            }
            CompositorError::GLError(atom, location) => {
                (rustler::Atom::from_str(env, atom).unwrap(), location).encode(env)
            }
        }
    }
}

impl From<CompositorError> for rustler::Error {
    fn from(error: CompositorError) -> Self {
        rustler::Error::Term(Box::new(error))
    }
}
