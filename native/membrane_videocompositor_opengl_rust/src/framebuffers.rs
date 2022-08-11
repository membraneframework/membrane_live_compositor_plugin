use glad_gles2::gl;

pub struct FramebufferObject {
  width: usize,
  height: usize,
  id: gl::GLuint,
  renderbuffer_id: gl::GLuint,
  _internal_format: gl::GLenum, // FIXME these should be custom enums instead of GLenum random ints
  format: gl::GLenum,
  type_: gl::GLenum,
}

impl FramebufferObject {
  pub fn new(
    width: usize,
    height: usize,
    internal_format: gl::GLenum,
    format: gl::GLenum,
    type_: gl::GLenum,
  ) -> Self {
    let mut id = 0;
    let mut renderbuffer_id = 0;

    unsafe {
      gl::GenFramebuffers(1, &mut id);
      gl::BindFramebuffer(gl::FRAMEBUFFER, id);

      gl::GenRenderbuffers(3, &mut renderbuffer_id);

      gl::BindRenderbuffer(gl::RENDERBUFFER, renderbuffer_id);
      gl::RenderbufferStorage(
        gl::RENDERBUFFER,
        internal_format,
        width as i32,
        height as i32,
      );
      gl::FramebufferRenderbuffer(
        gl::FRAMEBUFFER,
        gl::COLOR_ATTACHMENT0,
        gl::RENDERBUFFER,
        renderbuffer_id,
      );
    }

    Self {
      width,
      height,
      id,
      renderbuffer_id,
      _internal_format: internal_format,
      format,
      type_,
    }
  }

  fn bind_for_drawing(&self) {
    unsafe {
      gl::BindFramebuffer(gl::DRAW_FRAMEBUFFER, self.id);
      gl::DrawBuffers(1, [gl::COLOR_ATTACHMENT0].as_ptr());
      gl::Viewport(0, 0, self.width as i32, self.height as i32);
    }
  }

  fn bind_for_reading(&self) {
    unsafe {
      gl::BindFramebuffer(gl::READ_FRAMEBUFFER, self.id);
      gl::ReadBuffer(gl::COLOR_ATTACHMENT0);
    }
  }

  unsafe fn read_to_ptr(&self, ptr: *mut u8) {
    self.bind_for_reading();
    unsafe {
      gl::ReadPixels(
        0,
        0,
        self.width as i32,
        self.height as i32,
        self.format,
        self.type_,
        ptr as *mut std::ffi::c_void,
      )
    }
  }
}

impl Drop for FramebufferObject {
  fn drop(&mut self) {
    unsafe {
      gl::DeleteFramebuffers(1, &self.id);
      gl::DeleteRenderbuffers(1, &self.renderbuffer_id);
    }
  }
}

pub struct YUVRenderTarget {
  framebuffers: [FramebufferObject; 3],
  width: usize,
  height: usize,
}

impl YUVRenderTarget {
  pub fn new(width: usize, height: usize) -> Self {
    Self {
      framebuffers: [
        FramebufferObject::new(width, height, gl::R8, gl::RED, gl::UNSIGNED_BYTE),
        FramebufferObject::new(width / 2, height / 2, gl::R8, gl::RED, gl::UNSIGNED_BYTE),
        FramebufferObject::new(width / 2, height / 2, gl::R8, gl::RED, gl::UNSIGNED_BYTE),
      ],
      width,
      height,
    }
  }

  pub fn bind_for_drawing(&self, plane: Plane) {
    self.framebuffers[plane as usize].bind_for_drawing();
  }

  pub fn read(&self, buffer: &mut [u8]) {
    let pixels_amount = self.width * self.height;
    assert!(buffer.len() >= pixels_amount * 3 / 2);

    unsafe {
      self.framebuffers[0].bind_for_reading();
      self.framebuffers[0].read_to_ptr(buffer.as_mut_ptr());

      self.framebuffers[1].bind_for_reading();
      self.framebuffers[1].read_to_ptr(buffer.as_mut_ptr().add(pixels_amount));

      self.framebuffers[2].bind_for_reading();
      self.framebuffers[2].read_to_ptr(buffer.as_mut_ptr().add(pixels_amount * 5 / 4));
    }
  }
}

#[repr(usize)]
#[derive(Debug, Clone, Copy)]
pub enum Plane {
  Y = 0,
  U,
  V,
}
