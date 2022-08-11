use crate::{
  framebuffers::{self, YUVRenderTarget},
  shaders::ShaderProgram,
  textures::YUVPlanarTexture,
};
use glad_gles2::gl;

pub struct VideoPlacementTemplate {
  pub top_right: (f32, f32),
  pub top_left: (f32, f32),
  pub bot_left: (f32, f32),
  pub bot_right: (f32, f32),
  pub z_value: f32, // don't really know if setting this will do anything.. I guess it shouldn't without a depth buffer? FIXME??
}

impl VideoPlacementTemplate {
  const ELEMENTS: [u32; 6] = [0, 1, 3, 1, 2, 3];

  #[rustfmt::skip]
  fn as_vertex_array(&self) -> Vec<f32> {
    // FIXME: validate this
    vec![
      self.top_right.0, self.top_right.1, self.z_value, 1.0, 1.0,
      self.top_left.0,  self.top_left.1,  self.z_value, 0.0, 1.0,
      self.bot_left.0,  self.bot_left.1,  self.z_value, 0.0, 0.0,
      self.bot_right.0, self.bot_right.1, self.z_value, 1.0, 0.0,
    ]
  }
}

struct Video {
  vao: VertexArrayObject,
  textures: YUVPlanarTexture,
}

impl Video {
  fn new(placement: VideoPlacementTemplate, width: usize, height: usize) -> Self {
    Self {
      vao: VertexArrayObject::new(
        &placement.as_vertex_array(),
        &VideoPlacementTemplate::ELEMENTS,
      ),

      textures: YUVPlanarTexture::new(width, height),
    }
  }

  fn draw(&self) {
    self.textures.bind();
    self.vao.draw();
  }

  fn upload_texture(&self, data: &[u8]) {
    self.textures.load_frame(data);
  }
}

struct VertexArrayObject {
  id: gl::GLuint,
  vertices_id: gl::GLuint,
  elements_id: gl::GLuint,
  elements_len: usize,
}

impl VertexArrayObject {
  fn new(vertices: &[f32], elements: &[gl::GLuint]) -> Self {
    use std::ffi::c_void;
    unsafe {
      let mut id = 0;
      gl::GenVertexArrays(1, &mut id);
      gl::BindVertexArray(id);

      let mut buffers = [0, 0];
      gl::GenBuffers(2, buffers.as_mut_ptr());
      let [vertices_id, elements_id] = buffers;

      gl::BindBuffer(gl::ARRAY_BUFFER, vertices_id);
      gl::BufferData(
        gl::ARRAY_BUFFER,
        std::mem::size_of_val(vertices) as isize,
        vertices.as_ptr() as *const c_void,
        gl::STATIC_DRAW,
      );

      gl::VertexAttribPointer(
        0,
        3,
        gl::FLOAT,
        gl::FALSE,
        5 * std::mem::size_of::<f32>() as i32,
        std::ptr::null::<c_void>(),
      );
      gl::EnableVertexAttribArray(0);

      gl::VertexAttribPointer(
        1,
        2,
        gl::FLOAT,
        gl::FALSE,
        5 * std::mem::size_of::<f32>() as i32,
        (3 * std::mem::size_of::<f32>()) as *const c_void,
      );
      gl::EnableVertexAttribArray(1);

      gl::BindBuffer(gl::ELEMENT_ARRAY_BUFFER, elements_id);
      gl::BufferData(
        gl::ELEMENT_ARRAY_BUFFER,
        std::mem::size_of_val(elements) as isize,
        elements.as_ptr() as *const c_void,
        gl::STATIC_DRAW,
      );

      Self {
        id,
        vertices_id,
        elements_id,
        elements_len: elements.len(),
      }
    }
  }

  fn bind(&self) {
    unsafe { gl::BindVertexArray(self.id) }
  }

  fn unbind() {
    unsafe { gl::BindVertexArray(0) }
  }

  fn draw(&self) {
    use std::ffi::c_void;
    self.bind();
    unsafe {
      gl::DrawElements(
        gl::TRIANGLES,
        self.elements_len as i32,
        gl::UNSIGNED_INT,
        std::ptr::null::<c_void>(),
      )
    }
    Self::unbind();
  }
}

impl Drop for VertexArrayObject {
  fn drop(&mut self) {
    unsafe {
      let buffers = [self.vertices_id, self.elements_id];
      gl::DeleteBuffers(2, buffers.as_ptr());
      gl::DeleteVertexArrays(1, &self.id);
    }
  }
}

pub struct Scene {
  videos: Vec<Video>,
  render_target: YUVRenderTarget,
  shader_program: ShaderProgram,
}

impl Scene {
  pub fn new(out_width: usize, out_height: usize, shader_program: ShaderProgram) -> Self {
    Self {
      videos: Vec::new(),
      render_target: YUVRenderTarget::new(out_width, out_height),
      shader_program,
    }
  }

  pub fn add_video(
    &mut self,
    placement: VideoPlacementTemplate,
    width: usize,
    height: usize,
  ) -> usize {
    self.videos.push(Video::new(placement, width, height));
    self.videos.len() - 1
  }

  pub fn upload_texture(&self, video_idx: usize, data: &[u8]) {
    self.videos[video_idx].upload_texture(data);
  }

  pub fn draw_into(&self, buffer: &mut [u8]) {
    use framebuffers::Plane;
    self.shader_program.use_program();

    for plane in [Plane::Y, Plane::U, Plane::V] {
      self.render_target.bind_for_drawing(plane);
      // FIXME: This is a very ugly API, nothing suggests that you need to set this.
      //        This is how it's implemented in the C++ version, we can change this after we have a MVP
      self.shader_program.set_int("texture1", plane as i32);

      for video in self.videos.iter() {
        video.draw();
      }
    }
    self.render_target.read(buffer);
  }

  pub fn out_witdh(&self) -> usize {
    self.render_target.width() 
  }

  pub fn out_height(&self) -> usize {
    self.render_target.height() 
  }
}
