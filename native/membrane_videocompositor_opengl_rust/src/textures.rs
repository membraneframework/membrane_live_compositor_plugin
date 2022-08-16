use glad_gles2::gl;

pub struct YUVPlanarTexture {
  texture_ids: [gl::GLuint; 3],
  width: usize,
  height: usize,
}

impl YUVPlanarTexture {
  pub fn new(width: usize, height: usize) -> Self {
    let mut texture_ids = [0; 3];
    unsafe { gl::GenTextures(3, texture_ids.as_mut_ptr()) }

    for id in texture_ids {
      unsafe {
        gl::BindTexture(gl::TEXTURE_2D, id);
        gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_WRAP_S, gl::REPEAT as i32);
        gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_WRAP_T, gl::REPEAT as i32);
        gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_MIN_FILTER, gl::NEAREST as i32);
        gl::TexParameteri(gl::TEXTURE_2D, gl::TEXTURE_MAG_FILTER, gl::NEAREST as i32);
      }
    }

    Self {
      texture_ids,
      width,
      height,
    }
  }

  pub fn bind(&self) {
    for (i, &id) in self.texture_ids.iter().enumerate() {
      unsafe {
        gl::ActiveTexture(gl::TEXTURE0 + i as u32);
        gl::BindTexture(gl::TEXTURE_2D, id);
      }
    }
  }

  pub fn load_frame(&self, data: &[u8]) {
    let pixel_amount = self.width * self.height;
    assert!(data.len() == pixel_amount * 3 / 2);

    self.bind();

    unsafe {
      gl::ActiveTexture(gl::TEXTURE0);
      gl::TexImage2D(
        gl::TEXTURE_2D,
        0,
        gl::R8 as i32,
        self.width as i32,
        self.height as i32,
        0,
        gl::RED,
        gl::UNSIGNED_BYTE,
        data.as_ptr() as *const std::ffi::c_void,
      );

      gl::ActiveTexture(gl::TEXTURE1);
      gl::TexImage2D(
        gl::TEXTURE_2D,
        0,
        gl::R8 as i32,
        (self.width / 2) as i32,
        (self.height / 2) as i32,
        0,
        gl::RED,
        gl::UNSIGNED_BYTE,
        (data.as_ptr().add(pixel_amount)) as *const std::ffi::c_void,
      );

      gl::ActiveTexture(gl::TEXTURE2);
      gl::TexImage2D(
        gl::TEXTURE_2D,
        0,
        gl::R8 as i32,
        (self.width / 2) as i32,
        (self.height / 2) as i32,
        0,
        gl::RED,
        gl::UNSIGNED_BYTE,
        (data.as_ptr().add(pixel_amount * 5 / 4)) as *const std::ffi::c_void,
      );
    }
  }
}

impl Drop for YUVPlanarTexture {
  fn drop(&mut self) {
    unsafe { gl::DeleteTextures(3, self.texture_ids.as_ptr()) }
  }
}