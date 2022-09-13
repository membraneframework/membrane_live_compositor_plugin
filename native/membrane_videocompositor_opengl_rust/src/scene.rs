//! High-level structures, such as Scenes and Videos.

use crate::gl;
use std::collections::BTreeMap;

use crate::{
    errors::CompositorError,
    framebuffers::{self, YUVRenderTarget},
    shaders::ShaderProgram,
    textures::YUVPlanarTexture,
};
use glad_gles2::gl;

/// A point in 2D space
pub struct Point(pub f32, pub f32);

/// Describes where a video should be located in the scene space.
/// All coordinates have to be in the range [-1, 1].
pub struct VideoPlacementTemplate {
    pub top_right: Point,
    pub top_left: Point,
    pub bot_left: Point,
    pub bot_right: Point,
    /// This value is supposed to be used for making some videos appear 'in front of' other videos.
    /// This is still WIP and may not work.
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

/// Holds the [VertexArrayObject] and [YUVPlanarTexture] which together describe a single input video
struct Video {
    vao: VertexArrayObject, // FIXME: We shouldn't probably have a separate VAO for each video and just use transposition matrices for positioning the videos.
    textures: YUVPlanarTexture,
}

impl Video {
    /// Create a new video given a (placement template)[VideoPlacementTemplate] and the video's resolution.
    fn new(
        placement: VideoPlacementTemplate,
        width: usize,
        height: usize,
    ) -> Result<Self, CompositorError> {
        Ok(Self {
            vao: VertexArrayObject::new(
                &placement.as_vertex_array(),
                &VideoPlacementTemplate::ELEMENTS,
            )?,

            textures: YUVPlanarTexture::new(width, height)?,
        })
    }

    /// Draw this video into the currently attached render target
    fn draw(
        &self,
        _bind_proof: &framebuffers::DrawBoundYUVRenderTarget,
    ) -> Result<(), CompositorError> {
        self.textures.bind()?;
        self.vao.draw()?;
        Ok(())
    }

    /// Change the current frame of this video.
    fn upload_texture(&self, data: &[u8]) -> Result<(), CompositorError> {
        self.textures.load_frame(data)?;
        Ok(())
    }
}

/// An abstraction of OpenGL's [Vertex Array Object](<https://www.khronos.org/opengl/wiki/Vertex_Specification#Vertex_Array_Object>).
/// This struct also stores the vertex and elements buffer ids and deletes the whole thing when it is dropped.
///
/// It only does rendering in the `GL_TRIANGLES` mode and expects the drawn objects to have a texture.
struct VertexArrayObject {
    id: gl::GLuint,
    vertices_id: gl::GLuint,
    elements_id: gl::GLuint,
    elements_len: usize,
}

impl VertexArrayObject {
    /// Create a new instance given the `vertices` and `elements`
    ///
    /// This function assumes the following:
    ///  * all parameters are valid
    ///  * `vertices` should be in a specific format. Each vertex should have, in this order:
    ///    - 3 `f32`s in the [-1, 1] range describing the position.
    ///    - 2 `f32`s in the [0, 1] range describing the texture coordinates.
    ///  * `elements.len() % 3 == 0` (since `elements` should describe triangles)
    ///  * `elements` only contain GLuints in the [0, `vertices.len()`] range.
    fn new(vertices: &[f32], elements: &[gl::GLuint]) -> Result<Self, CompositorError> {
        use std::ffi::c_void;
        unsafe {
            let mut id = 0;
            gl!(gl::GenVertexArrays(1, &mut id))?;
            gl!(gl::BindVertexArray(id))?;

            let mut buffers = [0, 0];
            gl!(gl::GenBuffers(2, buffers.as_mut_ptr()))?;
            let [vertices_id, elements_id] = buffers;

            gl!(gl::BindBuffer(gl::ARRAY_BUFFER, vertices_id))?;
            gl!(gl::BufferData(
                gl::ARRAY_BUFFER,
                std::mem::size_of_val(vertices) as isize,
                vertices.as_ptr() as *const c_void,
                gl::STATIC_DRAW
            ))?;

            gl!(gl::VertexAttribPointer(
                0,
                3,
                gl::FLOAT,
                gl::FALSE,
                5 * std::mem::size_of::<f32>() as i32,
                std::ptr::null::<c_void>()
            ))?;
            gl!(gl::EnableVertexAttribArray(0))?;

            gl!(gl::VertexAttribPointer(
                1,
                2,
                gl::FLOAT,
                gl::FALSE,
                5 * std::mem::size_of::<f32>() as i32,
                (3 * std::mem::size_of::<f32>()) as *const c_void
            ))?;
            gl!(gl::EnableVertexAttribArray(1))?;

            gl!(gl::BindBuffer(gl::ELEMENT_ARRAY_BUFFER, elements_id))?;
            gl!(gl::BufferData(
                gl::ELEMENT_ARRAY_BUFFER,
                std::mem::size_of_val(elements) as isize,
                elements.as_ptr() as *const c_void,
                gl::STATIC_DRAW
            ))?;

            Ok(Self {
                id,
                vertices_id,
                elements_id,
                elements_len: elements.len(),
            })
        }
    }

    fn bind(&self) -> Result<(), CompositorError> {
        unsafe { gl!(gl::BindVertexArray(self.id))? }
        Ok(())
    }

    fn unbind() -> Result<(), CompositorError> {
        unsafe { gl!(gl::BindVertexArray(0))? }
        Ok(())
    }

    /// Draws this VAO. This function handles the binding and unbinding of this VAO as well.
    fn draw(&self) -> Result<(), CompositorError> {
        use std::ffi::c_void;
        self.bind()?;
        unsafe {
            gl!(gl::DrawElements(
                gl::TRIANGLES,
                self.elements_len as i32,
                gl::UNSIGNED_INT,
                std::ptr::null::<c_void>()
            ))?
        }
        Self::unbind()?;
        Ok(())
    }
}

impl Drop for VertexArrayObject {
    fn drop(&mut self) {
        unsafe {
            let buffers = [self.vertices_id, self.elements_id];
            gl!(gl::DeleteBuffers(2, buffers.as_ptr())).unwrap();
            gl!(gl::DeleteVertexArrays(1, &self.id)).unwrap();
        }
    }
}

/// Keeps all of the information and OpenGL components needed for composition.
/// Supports Adding new videos dynamically, but currently window positions are fixed after the videos are created. Videos also cannot be removed.
pub struct Scene {
    videos: BTreeMap<usize, Video>,
    render_target: YUVRenderTarget,
    shader_program: ShaderProgram,
}

impl Scene {
    /// Create a new Scene with a given output resolution and a `shader_program`. The shader program will be run for each plane in each video.
    /// An OpenGL context has to be current for the calling thread for this to work currently.
    pub fn new(
        out_width: usize,
        out_height: usize,
        shader_program: ShaderProgram,
    ) -> Result<Self, CompositorError> {
        // FIXME: the shader should probably be constructed in this function instead of being passed as an argument
        Ok(Self {
            videos: BTreeMap::new(),
            render_target: YUVRenderTarget::new(out_width, out_height)?,
            shader_program,
        })
    }

    /// Add a video to the scene.
    /// The video will be placed in an area specified by `placement`
    pub fn add_video(
        &mut self,
        video_idx: usize,
        placement: VideoPlacementTemplate,
        width: usize,
        height: usize,
    ) -> Result<(), CompositorError> {
        self.videos
            .insert(video_idx, Video::new(placement, width, height)?);
        Ok(())
    }

    /// Remove a video from the scene.
    pub fn remove_video(&mut self, video_idx: usize) -> Result<(), CompositorError> {
        match self.videos.remove(&video_idx) {
            Some(_) => Ok(()),
            None => Err(CompositorError::BadVideoIndex(
                "video_idx_remove_bad_index",
                video_idx,
            )),
        }
    }

    /// Upload a texture to a video specified by the `video_idx`
    ///
    /// # Panics
    ///
    /// This function will panic if `data` doesn't have proper length for a YUV420p-encoded frame for the specified video.
    pub fn upload_texture(&self, video_idx: usize, data: &[u8]) -> Result<(), CompositorError> {
        self.videos
            .get(&video_idx)
            .ok_or(CompositorError::BadVideoIndex(
                "video_idx_upload_bad_index",
                video_idx,
            ))?
            .upload_texture(data)?;
        Ok(())
    }

    /// Render the current state of the scene and copy the result into `buffer`
    ///
    /// # Panics
    ///
    /// This function will panic if the `buffer` is not long enough to hold the resulting image.

    pub fn draw_into(&mut self, buffer: &mut [u8]) -> Result<(), CompositorError> {
        use framebuffers::Plane;
        self.shader_program.use_program()?;

        for plane in [Plane::Y, Plane::U, Plane::V] {
            let bind_proof = self.render_target.bind_for_drawing(plane)?;
            // FIXME: This is a very ugly API, nothing suggests that you need to set this.
            //        This is how it's implemented in the C++ version, we can change this after we have a MVP
            self.shader_program.set_int("texture1", plane as i32)?;

            for video in self.videos.values() {
                video.draw(&bind_proof)?;
            }
        }
        self.render_target.read(buffer)?;

        Ok(())
    }

    /// Width of the Y plane of the images produced by rendering this scene
    pub fn out_width(&self) -> usize {
        self.render_target.width()
    }

    /// Height of the Y plane of the images produced by rendering this scene
    pub fn out_height(&self) -> usize {
        self.render_target.height()
    }
}
