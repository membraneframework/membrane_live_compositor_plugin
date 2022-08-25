use crate::gl;
use thiserror::Error;

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.OpenGL.Rust.ErrorLocation"]
/// Carries information about a location where an error happened
pub struct ErrorLocation {
    pub file: String,
    pub line: u32,
    pub call: String,
}

pub fn result_or_gl_error<T>(
    res: T,
    err: u32,
    location: ErrorLocation,
) -> Result<T, CompositorError> {
    match err {
        gl!(NO_ERROR) => Ok(res),
        gl!(INVALID_ENUM) => Err(CompositorError::GLError("gl_invalid_enum", location)),
        gl!(INVALID_VALUE) => Err(CompositorError::GLError("gl_invalid_value", location)),
        gl!(INVALID_OPERATION) => Err(CompositorError::GLError("gl_invalid_opegation", location)),
        gl!(INVALID_FRAMEBUFFER_OPERATION) => Err(CompositorError::GLError(
            "gl_invalid_framebuffer_operations",
            location,
        )),
        gl!(OUT_OF_MEMORY) => Err(CompositorError::GLError("gl_out_of_memory", location)),
        _ => panic!("Error passed to result_or_gl_error is not an OpenGL error"),
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
