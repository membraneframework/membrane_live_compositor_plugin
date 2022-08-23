//! Structures for managing OpenGL textures

use crate::{errors::CompositorError, gl};

/// An abstraction of OpenGL's [textures](https://www.khronos.org/opengl/wiki/Texture) bundled together so that every texture represents a separate YUV420p plane
pub struct YUVPlanarTexture {
    texture_ids: [gl!(GLuint); 3],
    width: usize,
    height: usize,
}

impl YUVPlanarTexture {
    /// Create a new texture. `width` and `height` specify the resolution of the Y plane and should be specified in pixels.
    pub fn new(width: usize, height: usize) -> Result<Self, CompositorError> {
        let mut texture_ids = [0; 3];
        unsafe { gl!(GenTextures(3, texture_ids.as_mut_ptr()))? }

        for id in texture_ids {
            unsafe {
                gl!(BindTexture(gl!(TEXTURE_2D), id))?;
                gl!(TexParameteri(
                    gl!(TEXTURE_2D),
                    gl!(TEXTURE_WRAP_S),
                    gl!(REPEAT) as i32
                ))?;
                gl!(TexParameteri(
                    gl!(TEXTURE_2D),
                    gl!(TEXTURE_WRAP_T),
                    gl!(REPEAT) as i32
                ))?;
                gl!(TexParameteri(
                    gl!(TEXTURE_2D),
                    gl!(TEXTURE_MIN_FILTER),
                    gl!(NEAREST) as i32
                ))?;
                gl!(TexParameteri(
                    gl!(TEXTURE_2D),
                    gl!(TEXTURE_MAG_FILTER),
                    gl!(NEAREST) as i32
                ))?;
            }
        }

        Ok(Self {
            texture_ids,
            width,
            height,
        })
    }

    /// Bind these textures.
    ///
    /// The textures for YUV planes will be bound to `GL_TEXTURE0`, `GL_TEXTURE1` and `GL_TEXTURE2` respectively.
    pub fn bind(&self) -> Result<(), CompositorError> {
        for (i, &id) in self.texture_ids.iter().enumerate() {
            unsafe {
                gl!(ActiveTexture(gl!(TEXTURE0) + i as u32))?;
                gl!(BindTexture(gl!(TEXTURE_2D), id))?;
            }
        }

        Ok(())
    }

    /// Load a frame into this texture.
    ///
    /// # Panics
    ///
    /// This function will panic if the length of `data` is not equal to the amount of data this texture needs for loading (`width * height * 3 / 2`).
    pub fn load_frame(&self, data: &[u8]) -> Result<(), CompositorError> {
        let pixel_amount = self.width * self.height;
        assert!(data.len() == pixel_amount * 3 / 2);

        self.bind()?;

        unsafe {
            gl!(ActiveTexture(gl!(TEXTURE0)))?;
            gl!(TexImage2D(
                gl!(TEXTURE_2D),
                0,
                gl!(R8) as i32,
                self.width as i32,
                self.height as i32,
                0,
                gl!(RED),
                gl!(UNSIGNED_BYTE),
                data.as_ptr() as *const std::ffi::c_void
            ))?;

            gl!(ActiveTexture(gl!(TEXTURE1)))?;
            gl!(TexImage2D(
                gl!(TEXTURE_2D),
                0,
                gl!(R8) as i32,
                (self.width / 2) as i32,
                (self.height / 2) as i32,
                0,
                gl!(RED),
                gl!(UNSIGNED_BYTE),
                (data.as_ptr().add(pixel_amount)) as *const std::ffi::c_void
            ))?;

            gl!(ActiveTexture(gl!(TEXTURE2)))?;
            gl!(TexImage2D(
                gl!(TEXTURE_2D),
                0,
                gl!(R8) as i32,
                (self.width / 2) as i32,
                (self.height / 2) as i32,
                0,
                gl!(RED),
                gl!(UNSIGNED_BYTE),
                (data.as_ptr().add(pixel_amount * 5 / 4)) as *const std::ffi::c_void
            ))?;
        }

        Ok(())
    }
}

impl Drop for YUVPlanarTexture {
    fn drop(&mut self) {
        unsafe { gl!(DeleteTextures(3, self.texture_ids.as_ptr())).unwrap() }
    }
}
