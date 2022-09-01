//! Structures for managing OpenGL shaders and shader programs

use crate::{errors::CompositorError, gl};
use glad_gles2::gl;

/// An abstraction of OpenGL's [shader program](https://www.khronos.org/opengl/wiki/GLSL_Object#Program_objects).
/// This will delete the program when dropped.
pub struct ShaderProgram {
    id: gl::GLuint,
}

impl ShaderProgram {
    /// Create a new ShaderProgram from the vertex and fragment shader source code
    pub fn new(
        vertex_shader_code: &str,
        fragment_shader_code: &str,
    ) -> Result<Self, CompositorError> {
        unsafe {
            let vertex = gl!(gl::CreateShader(gl::VERTEX_SHADER))?;
            gl!(gl::ShaderSource(
                vertex,
                1,
                &(vertex_shader_code.as_ptr() as *const i8),
                &(vertex_shader_code.len() as i32)
            ))?;

            gl!(gl::CompileShader(vertex))?;
            Self::check_shader_compilation_error(vertex, ShaderType::Vertex)?;

            let fragment = gl!(gl::CreateShader(gl::FRAGMENT_SHADER))?;
            gl!(gl::ShaderSource(
                fragment,
                1,
                &(fragment_shader_code.as_ptr() as *const i8),
                &(fragment_shader_code.len() as i32)
            ))?;

            gl!(gl::CompileShader(fragment))?;
            Self::check_shader_compilation_error(fragment, ShaderType::Fragment)?;

            let program = gl!(gl::CreateProgram())?;
            gl!(gl::AttachShader(program, vertex))?;
            gl!(gl::AttachShader(program, fragment))?;
            gl!(gl::LinkProgram(program))?;
            Self::check_program_linking_error(program)?;

            gl!(gl::DeleteShader(vertex))?;
            gl!(gl::DeleteShader(fragment))?;

            Ok(Self { id: program })
        }
    }

    /// Make OpenGL use this program.
    pub fn use_program(&self) -> Result<(), CompositorError> {
        unsafe { gl!(gl::UseProgram(self.id))? }
        Ok(())
    }

    /// Set an integer uniform with the given `name` to the `value` in this program.
    pub fn set_int(&self, name: &str, value: i32) -> Result<(), CompositorError> {
        use std::ffi::CString;
        let name_c_str = CString::new(name).unwrap(); // ok to unwrap since name is known before compilation
        unsafe {
            gl!(gl::Uniform1i(
                gl!(gl::GetUniformLocation(self.id, name_c_str.as_ptr()))?,
                value
            ))?
        }
        Ok(())
    }

    fn check_shader_compilation_error(
        shader_id: gl::GLuint,
        shader_type: ShaderType,
    ) -> Result<(), CompositorError> {
        use std::ffi::CString;

        let mut ok = 0;
        unsafe {
            gl!(gl::GetShaderiv(shader_id, gl::COMPILE_STATUS, &mut ok))?;
            if ok == gl::TRUE.into() {
                return Ok(());
            }

            let mut log_length = 0;
            gl!(gl::GetShaderiv(
                shader_id,
                gl::INFO_LOG_LENGTH,
                &mut log_length
            ))?;

            let error_log = if log_length <= 0 {
                String::new()
            } else {
                let buffer = CString::new(" ".repeat(log_length as usize))
                    .unwrap()
                    .into_raw();
                gl!(gl::GetShaderInfoLog(
                    shader_id,
                    log_length + 1,
                    std::ptr::null_mut(),
                    buffer
                ))?;
                CString::from_raw(buffer).to_str().unwrap().to_string()
            };

            match shader_type {
                ShaderType::Vertex => Err(CompositorError::ShaderError {
                    atom: "cannot_compile_vertex_shader",
                    error_log,
                }),
                ShaderType::Fragment => Err(CompositorError::ShaderError {
                    atom: "cannot_compile_fragment_shader",
                    error_log,
                }),
            }
        }
    }

    fn check_program_linking_error(program_id: gl::GLuint) -> Result<(), CompositorError> {
        use std::ffi::CString;

        let mut ok = 0;
        unsafe {
            gl!(gl::GetProgramiv(program_id, gl::LINK_STATUS, &mut ok))?;
            if ok == gl::TRUE.into() {
                return Ok(());
            }

            let mut log_length = 0;
            gl!(gl::GetProgramiv(
                program_id,
                gl::INFO_LOG_LENGTH,
                &mut log_length
            ))?;

            let error_log = if log_length <= 0 {
                String::new()
            } else {
                let buffer = CString::new(" ".repeat(log_length as usize))
                    .unwrap()
                    .into_raw();
                gl!(gl::GetProgramInfoLog(
                    program_id,
                    log_length + 1,
                    std::ptr::null_mut(),
                    buffer
                ))?;
                CString::from_raw(buffer).to_str().unwrap().to_string()
            };

            Err(CompositorError::ShaderError {
                atom: "cannot_link_program",
                error_log,
            })
        }
    }
}

impl Drop for ShaderProgram {
    fn drop(&mut self) {
        unsafe { gl!(gl::DeleteProgram(self.id)).unwrap() }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ShaderType {
    Vertex,
    Fragment,
}
