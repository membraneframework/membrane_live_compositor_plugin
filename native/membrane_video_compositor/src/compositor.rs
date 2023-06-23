use std::sync::{Arc, Mutex};

use membrane_video_compositor_common::elixir_transfer::{
    CustomStructElixirPacket, StructElixirPacket, TransformationElixirPacket,
};
use membrane_video_compositor_common::plugins::layout::UntypedLayout;
use membrane_video_compositor_common::plugins::transformation::{
    Transformation, UntypedTransformation,
};
use membrane_video_compositor_common::plugins::{PluginArgumentEncoder, PluginRegistryKey};
use membrane_video_compositor_common::texture::Texture;
use membrane_video_compositor_common::WgpuCtx;

use self::errors::CompositorError;
use self::registry::PluginRegistry;

pub mod errors;
mod registry;
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
    wgpu_ctx: Arc<WgpuCtx>,
    plugin_registry: PluginRegistry,
}

impl InnerState {
    fn new() -> Self {
        Self {
            wgpu_ctx: Arc::new(wgpu_interface::create_new_wgpu_context()),
            plugin_registry: PluginRegistry::new(),
        }
    }

    pub fn wgpu_ctx(&self) -> Arc<WgpuCtx> {
        self.wgpu_ctx.clone()
    }

    pub fn register_transformation(
        &mut self,
        transformation: Arc<dyn UntypedTransformation>,
    ) -> Result<(), CompositorError> {
        self.plugin_registry.register(
            transformation.registry_key(),
            registry::PluginRegistryEntry::Transformation(transformation),
        )?;
        Ok(())
    }

    pub fn register_layout(
        &mut self,
        layout: Arc<dyn UntypedLayout>,
    ) -> Result<(), CompositorError> {
        self.plugin_registry.register(
            layout.registry_key(),
            registry::PluginRegistryEntry::Layout(layout),
        )?;
        Ok(())
    }
}

pub struct MockTransformation {}

impl MockTransformation {
    const NAME: &str = "mock_transformation";
}

impl PluginArgumentEncoder for MockTransformation {
    type Arg = String;

    fn registry_key() -> PluginRegistryKey<'static>
    where
        Self: Sized,
    {
        PluginRegistryKey(Self::NAME)
    }
}

impl Transformation for MockTransformation {
    type Error = ();

    fn apply(
        &self,
        arg: &Self::Arg,
        _source: &Texture,
        _target: &Texture,
    ) -> Result<(), Self::Error> {
        println!("This is a mock transformation called with the string \"{arg}\" :^)");
        Ok(())
    }

    fn new(_ctx: Arc<WgpuCtx>) -> Self
    where
        Self: Sized,
    {
        Self {}
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn mock_transformation(ctx: StructElixirPacket<WgpuCtx>) -> TransformationElixirPacket {
    let ctx = unsafe { ctx.decode() };
    unsafe { TransformationElixirPacket::encode(MockTransformation::new(ctx)) }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn encode_mock_transformation(
    arg: <MockTransformation as PluginArgumentEncoder>::Arg,
) -> CustomStructElixirPacket {
    unsafe { MockTransformation::encode_arg(arg) }
}
