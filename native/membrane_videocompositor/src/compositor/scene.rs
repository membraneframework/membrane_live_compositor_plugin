use std::collections::HashMap;

use super::{texture_transformations::TextureTransformation, VideoPlacement};

type VideoId = u32;

#[derive(Debug)]
pub struct Scene {
    pub videos_configs: HashMap<VideoId, VideoConfig>,
}

impl Scene {
    pub fn empty() -> Self {
        Self {
            videos_configs: HashMap::new(),
        }
    }
}

#[derive(Debug)]
pub struct VideoConfig {
    pub placement: VideoPlacement,
    pub texture_transformations: Vec<Box<dyn TextureTransformation>>,
}
