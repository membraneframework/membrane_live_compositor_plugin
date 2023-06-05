use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use membrane_video_compositor_common::elixir_transfer::{
    StructElixirPacket, TransformationElixirPacket,
};
use membrane_video_compositor_common::plugins::layout::UntypedLayout;
use membrane_video_compositor_common::plugins::transformation::{
    Transformation, UntypedTransformation,
};
use membrane_video_compositor_common::WgpuContext;

use self::errors::NewCompositorError;

pub mod errors;
mod wgpu_interface;

pub struct State(Mutex<InnerState>);

impl std::ops::Deref for State {
    type Target = Mutex<InnerState>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl State {
    pub fn new() -> Self {
        Self(Mutex::new(InnerState::new()))
    }
}

impl Default for State {
    fn default() -> Self {
        Self::new()
    }
}

pub struct InnerState {
    wgpu_ctx: Arc<WgpuContext>,
    transformations: HashMap<&'static str, Arc<dyn UntypedTransformation>>,
    layouts: HashMap<&'static str, Arc<dyn UntypedLayout>>,
}

impl InnerState {
    fn new() -> Self {
        Self {
            wgpu_ctx: Arc::new(wgpu_interface::create_new_wgpu_context()),
            transformations: HashMap::new(),
            layouts: HashMap::new(),
        }
    }

    pub fn wgpu_ctx(&self) -> Arc<WgpuContext> {
        self.wgpu_ctx.clone()
    }

    pub fn register_transformation(
        &mut self,
        transformation: Arc<dyn UntypedTransformation>,
    ) -> Result<(), NewCompositorError> {
        if self.transformations.contains_key(transformation.name()) {
            return Err(NewCompositorError::TransformationNameTaken(
                transformation.name().to_string(),
            ));
        }

        self.transformations
            .insert(transformation.name(), transformation);

        Ok(())
    }

    pub fn register_layout(
        &mut self,
        layout: Arc<dyn UntypedLayout>,
    ) -> Result<(), NewCompositorError> {
        if self.layouts.contains_key(layout.name()) {
            return Err(NewCompositorError::LayoutNameTaken(
                layout.name().to_string(),
            ));
        }

        self.layouts.insert(layout.name(), layout);
        Ok(())
    }
}

struct MockTransformation {}

impl Transformation for MockTransformation {
    type Arg = String;

    fn name(&self) -> &'static str {
        "mock_transformation"
    }

    fn do_stuff(&self, arg: &Self::Arg) {
        println!("This is a mock transformation called with the string \"{arg}\" :^)")
    }

    fn new(_ctx: Arc<WgpuContext>) -> Self
    where
        Self: Sized,
    {
        Self {}
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn mock_transformation(ctx: StructElixirPacket<WgpuContext>) -> TransformationElixirPacket {
    let ctx = unsafe { ctx.decode() };
    unsafe { TransformationElixirPacket::encode(MockTransformation::new(ctx)) }
}
