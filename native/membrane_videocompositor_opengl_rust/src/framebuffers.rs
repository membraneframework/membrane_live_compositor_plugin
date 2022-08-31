//! Structures for managing various OpenGL render targets
use glad_gles2::gl;

/// An abstraction for an individual [framebuffer object](<https://www.khronos.org/opengl/wiki/Framebuffer_Object>) with an attached [renderbuffer](<https://www.khronos.org/opengl/wiki/Renderbuffer_Object>).
struct FramebufferObject {
    width: usize,
    height: usize,
    id: gl::GLuint,
    renderbuffer_id: gl::GLuint,
    _internal_format: gl::GLenum, // FIXME these should be custom enums instead of GLenum random ints
    output_format: gl::GLenum,
    output_type: gl::GLenum,
    draw_bound: bool,
}

impl FramebufferObject {
    /// Create a new instance.
    ///  * `width` and `height` should be given in pixels.
    ///  * `internal_format` is the format used by the renderbuffer internally (e.g `gl::RGB8` or `gl::R8`)
    ///  * `output_format` and `output_type` represent the type and format we expect to get out when reading from the framebuffer (e.g. `gl::RGB` for `format` and `gl::UNSIGNED_BYTE` for `output_type`)
    fn new(
        width: usize,
        height: usize,
        internal_format: gl::GLenum,
        output_format: gl::GLenum,
        output_type: gl::GLenum,
    ) -> Self {
        let mut id = 0;
        let mut renderbuffer_id = 0;

        unsafe {
            gl::GenFramebuffers(1, &mut id);
            gl::BindFramebuffer(gl::FRAMEBUFFER, id);

            gl::GenRenderbuffers(1, &mut renderbuffer_id);

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
            output_format,
            output_type,
            draw_bound: false,
        }
    }

    fn bind_for_drawing(&mut self) {
        unsafe {
            gl::BindFramebuffer(gl::DRAW_FRAMEBUFFER, self.id);
            gl::DrawBuffers(1, [gl::COLOR_ATTACHMENT0].as_ptr());
            gl::Viewport(0, 0, self.width as i32, self.height as i32);
        }

        self.draw_bound = true;
    }

    fn unbind_drawing(&mut self) {
        assert!(self.draw_bound);
        unsafe { gl::BindFramebuffer(gl::DRAW_FRAMEBUFFER, 0) }
    }

    fn bind_for_reading(&self) {
        unsafe {
            gl::BindFramebuffer(gl::READ_FRAMEBUFFER, self.id);
            gl::ReadBuffer(gl::COLOR_ATTACHMENT0);
        }
    }

    /// Read the contents of `self` to a pointer.
    ///
    /// # Safety
    /// The caller must ensure `ptr` points to an array long enough to contain all of the contents.
    unsafe fn read_to_ptr(&self, ptr: *mut u8) {
        self.bind_for_reading();
        unsafe {
            gl::ReadPixels(
                0,
                0,
                self.width as i32,
                self.height as i32,
                self.output_format,
                self.output_type,
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

/// A render target suitable for rendering YUV420p frames.
/// Because this is a planar format in which not all planes have the same resolution, the rendering has to be done separately for each frame.
/// That is why we have 3 separate framebuffers in this struct.
pub struct YUVRenderTarget {
    framebuffers: [FramebufferObject; 3],
    width: usize,
    height: usize,
    bound_plane: Option<Plane>,
}

impl YUVRenderTarget {
    /// Create a new instance.
    /// `width` and `height` should be the dimensions of the Y plane in pixels
    pub fn new(width: usize, height: usize) -> Self {
        Self {
            framebuffers: [
                FramebufferObject::new(width, height, gl::R8, gl::RED, gl::UNSIGNED_BYTE),
                FramebufferObject::new(width / 2, height / 2, gl::R8, gl::RED, gl::UNSIGNED_BYTE),
                FramebufferObject::new(width / 2, height / 2, gl::R8, gl::RED, gl::UNSIGNED_BYTE),
            ],
            width,
            height,
            bound_plane: None,
        }
    }

    /// Select a [Plane], into which images will be rendered
    pub fn bind_for_drawing(&mut self, plane: Plane) -> DrawBoundYUVRenderTarget {
        self.framebuffers[plane as usize].bind_for_drawing();
        self.bound_plane = Some(plane);
        DrawBoundYUVRenderTarget { target: self }
    }

    /// Copy the contents of the whole render target (all planes) into a `buffer`
    ///
    /// # Panics
    ///
    /// Panics if the buffer is not long enough for the contents to fit.
    pub fn read(&self, buffer: &mut [u8]) {
        let pixels_amount = self.width * self.height;
        assert!(buffer.len() >= pixels_amount * 3 / 2);

        unsafe {
            self.framebuffers[0].read_to_ptr(buffer.as_mut_ptr());

            self.framebuffers[1].read_to_ptr(buffer.as_mut_ptr().add(pixels_amount));

            self.framebuffers[2].read_to_ptr(buffer.as_mut_ptr().add(pixels_amount * 5 / 4));
        }
    }

    /// Get the width of the Y plane.
    pub fn width(&self) -> usize {
        self.width
    }

    /// Get the height of the Y plane.
    pub fn height(&self) -> usize {
        self.height
    }
}

pub struct DrawBoundYUVRenderTarget<'a> {
    target: &'a mut YUVRenderTarget,
}

impl<'a> Drop for DrawBoundYUVRenderTarget<'a> {
    fn drop(&mut self) {
        self.target.framebuffers[self.target.bound_plane.unwrap() as usize].unbind_drawing();
        self.target.bound_plane = None;
    }
}

/// Represents a plane in a YUV planar image format.
#[repr(usize)]
#[derive(Debug, Clone, Copy)]
pub enum Plane {
    Y = 0,
    U,
    V,
}
