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
  ) -> Result<Self, ShaderError> {
    unsafe {
      let vertex = gl::CreateShader(gl::VERTEX_SHADER);
      gl::ShaderSource(
        vertex,
        1,
        &(vertex_shader_code.as_ptr() as *const i8),
        &(vertex_shader_code.len() as i32),
      );

      gl::CompileShader(vertex);
      let mut ok = 0;
      gl::GetShaderiv(vertex, gl::COMPILE_STATUS, &mut ok);
      if ok != gl::TRUE.into() {
        return Err(ShaderError::CantCompileVertexShader);
      }

      let fragment = gl::CreateShader(gl::FRAGMENT_SHADER);
      gl::ShaderSource(
        fragment,
        1,
        &(fragment_shader_code.as_ptr() as *const i8),
        &(fragment_shader_code.len() as i32),
      );

      gl::CompileShader(fragment);
      gl::GetShaderiv(fragment, gl::COMPILE_STATUS, &mut ok);
      if ok != gl::TRUE.into() {
        return Err(ShaderError::CantCompileFragmentShader);
      }

      let program = gl::CreateProgram();
      gl::AttachShader(program, vertex);
      gl::AttachShader(program, fragment);
      gl::LinkProgram(program);

      gl::GetProgramiv(program, gl::LINK_STATUS, &mut ok);
      if ok != gl::TRUE.into() {
        return Err(ShaderError::CantLinkProgram);
      }

      gl::DeleteShader(vertex);
      gl::DeleteShader(fragment);

      Ok(Self { id: program })
    }
  }

  /// Make OpenGL use this program.
  pub fn use_program(&self) {
    unsafe { gl::UseProgram(self.id) }
  }

  /// Set an integer uniform with the given `name` to the `value` in this program.
  pub fn set_int(&self, name: &str, value: i32) {
    use std::ffi::CString;
    let name_c_str = CString::new(name).unwrap(); // ok to unwrap since name is known before compilation
    unsafe {
      gl::Uniform1i(
        gl::GetUniformLocation(self.id, name_c_str.as_ptr()),
        value,
      )
    }
  }
}

impl Drop for ShaderProgram {
  fn drop(&mut self) {
    unsafe { gl::DeleteProgram(self.id) }
  }
}

/// Represents errors that can happen when interacting with shaders. This error can be converted to a rustler error, which makes the `?` operator work very nicely here.
pub enum ShaderError {
  CantCompileFragmentShader,
  CantCompileVertexShader,
  CantLinkProgram,
}

mod atoms {
  rustler::atoms! {
    cant_compile_fragment_shader,
    cant_compile_vertex_shader,
    cant_link_program
  }
}

impl From<ShaderError> for rustler::Error {
  fn from(err: ShaderError) -> Self {
    match err {
      ShaderError::CantCompileFragmentShader => {
        rustler::Error::Term(Box::new(atoms::cant_compile_fragment_shader()))
      }
      ShaderError::CantCompileVertexShader => {
        rustler::Error::Term(Box::new(atoms::cant_compile_vertex_shader()))
      }
      ShaderError::CantLinkProgram => rustler::Error::Term(Box::new(atoms::cant_link_program())),
    }
  }
}
