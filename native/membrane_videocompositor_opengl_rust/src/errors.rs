use crate::{gl, shaders::ShaderError};

#[derive(Debug, rustler::NifStruct)]
#[module = "Membrane.VideoCompositor.OpenGL.Rust.ErrorLocation"]
pub struct ErrorLocation {
    pub file: String,
    pub line: u32,
    pub call: String,
}

#[derive(Debug)]
pub enum GLError {
    InvalidEnum(ErrorLocation),
    InvalidValue(ErrorLocation),
    InvalidOperation(ErrorLocation),
    InvalidFramebufferOperation(ErrorLocation),
    OutOfMemory(ErrorLocation),
}

pub fn result_or_gl_error<T>(res: T, err: u32, location: ErrorLocation) -> Result<T, GLError> {
    match err {
        gl!(NO_ERROR) => Ok(res),
        gl!(INVALID_ENUM) => Err(GLError::InvalidEnum(location)),
        gl!(INVALID_VALUE) => Err(GLError::InvalidValue(location)),
        gl!(INVALID_OPERATION) => Err(GLError::InvalidOperation(location)),
        gl!(INVALID_FRAMEBUFFER_OPERATION) => Err(GLError::InvalidFramebufferOperation(location)),
        gl!(OUT_OF_MEMORY) => Err(GLError::OutOfMemory(location)),
        _ => panic!("Error passed to result_or_gl_error is not an OpenGL error"),
    }
}

mod atoms {
    rustler::atoms! {
        invalid_enum,
        invalid_value,
        invalid_operation,
        invalid_framebuffer_operation,
        out_of_memory
    }
}

impl From<GLError> for rustler::Error {
    fn from(error: GLError) -> Self {
        use rustler::Error;
        match error {
            GLError::InvalidEnum(location) => {
                Error::Term(Box::new((atoms::invalid_enum(), location)))
            }
            GLError::InvalidValue(location) => {
                Error::Term(Box::new((atoms::invalid_value(), location)))
            }
            GLError::InvalidOperation(location) => {
                Error::Term(Box::new((atoms::invalid_operation(), location)))
            }
            GLError::InvalidFramebufferOperation(location) => {
                Error::Term(Box::new((atoms::invalid_framebuffer_operation(), location)))
            }
            GLError::OutOfMemory(location) => {
                Error::Term(Box::new((atoms::out_of_memory(), location)))
            }
        }
    }
}

pub enum CompositorError {
    ShaderError(ShaderError),
    GLError(GLError),
}

impl From<ShaderError> for CompositorError {
    fn from(error: ShaderError) -> Self {
        Self::ShaderError(error)
    }
}

impl From<GLError> for CompositorError {
    fn from(error: GLError) -> Self {
        Self::GLError(error)
    }
}

impl From<CompositorError> for rustler::Error {
    fn from(error: CompositorError) -> Self {
        match error {
            CompositorError::ShaderError(error) => error.into(),
            CompositorError::GLError(error) => error.into(),
        }
    }
}
