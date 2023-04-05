use std::sync::Arc;

#[derive(Debug)]
pub enum Node {
    Layout {
        resolution: crate::elixir_bridge::elixir_structs::LayoutOutputResolution,
        implementation: usize,
        inputs: std::collections::HashMap<
            crate::elixir_bridge::elixir_structs::LayoutInternalName,
            Arc<Node>,
        >,
    },

    Transformation {
        resolution: crate::elixir_bridge::elixir_structs::TextureOutputResolution,
        previous: Arc<Node>,
        transformation: usize,
    },

    Video {
        pad: crate::elixir_bridge::elixir_structs::PadRef,
    },
}

#[derive(Debug)]
pub struct Scene {
    pub final_node: Arc<Node>,
}
