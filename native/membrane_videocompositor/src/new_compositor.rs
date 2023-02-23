use std::sync::{Arc, Mutex};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct VideoId(usize);

pub struct Frame {}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Timestamp(u64);

pub struct MockScene {}

#[derive(Debug, thiserror::Error)]
pub enum CreatingCompositorError {}

#[derive(Debug, thiserror::Error)]
pub enum UpdateSceneError {}

#[derive(Debug, thiserror::Error)]
pub enum ComposeError {}

pub struct Compositor {
    scene: MockScene,

    // I keep this in an Arc<Mutex<>> so that the frame queueing mechanism can have
    // references to this stuff to upload frames to the gpu memory. Is this a good idea?
    // should the queue be able to do that, or would that be a bad separation of concerns?
    //
    // If the queue uploads the frames, this part of the compositor does not need to be
    // concerned with stream format changes etc.
    _wgpu: Arc<Mutex<(wgpu::Device, wgpu::Adapter)>>,
}

impl Compositor {
    pub fn new(
        _wgpu: Arc<Mutex<(wgpu::Device, wgpu::Queue)>>,
    ) -> Result<Self, CreatingCompositorError> {
        todo!()
    }

    pub fn update_scene(&mut self, scene: MockScene) -> Result<(), UpdateSceneError> {
        self.scene = scene;
        todo!()
    }

    /// ## Parameters:
    ///  - `frames`: a `Vec` with a frame for each video present in the scene
    ///  - `pts`: the pts of the composed frame. This value can be used in transformations
    ///    that require temporal information (e.g. fade-outs)
    pub fn compose(
        &self,
        _frames: Vec<(VideoId, Frame)>,
        _pts: Timestamp,
    ) -> Result<Frame, ComposeError> {
        todo!()
    }
}

// Open questions:
//  - do we need pts for each frame? I think we don't and components that use time information
//    should use the timestamp of the whole frame as their time reference, but I would love to
//    hear some opinions on that
