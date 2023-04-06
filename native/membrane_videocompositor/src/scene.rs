use std::{collections::HashMap, sync::Arc};

use crate::elixir_bridge::elixir_structs::{
    LayoutInternalName, LayoutOutputResolution, PadRef, TextureOutputResolution,
};

/// A node represents a single render, which typically means the application
/// of one filter/layout
#[derive(Debug)]
pub enum Node {
    /// A layout is a transformation, which can take many inputs and produce a single output.
    /// This could, for example, arrange a couple of videos in a grid.
    Layout {
        resolution: LayoutOutputResolution,
        implementation: usize,
        inputs: HashMap<LayoutInternalName, Arc<Node>>,
    },

    /// A transformation is a single-input-single-output filter.
    /// An example of a transformation could be a node that rounds the corners of a video.
    Transformation {
        resolution: TextureOutputResolution,
        previous: Arc<Node>,
        transformation: usize,
    },

    /// This represents the node, through which video frames 'enter' the scene graph.
    Video { pad: PadRef },
}

/// A scene represents the full pipeline from video inputs (that come via Membrane pads)
/// to outputs. It holds a reference to a [Node] which represents the final frame that will be rendered,
/// which will then be returned to elixir and sent out to the next Membrane element.
#[derive(Debug)]
pub struct Scene {
    pub final_node: Arc<Node>,
}
