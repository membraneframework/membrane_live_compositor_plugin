use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use membrane_video_compositor_common::elixir_transfer::{
    CustomStructElixirPacket, StructElixirPacket, TransformationElixirPacket,
};
use membrane_video_compositor_common::plugins::layout::UntypedLayout;
use membrane_video_compositor_common::plugins::transformation::{
    Transformation, UntypedTransformation,
};
use membrane_video_compositor_common::plugins::{CustomProcessor, PluginRegistryKey};
use membrane_video_compositor_common::WgpuContext;

use self::errors::CompositorError;

pub mod errors;
mod wgpu_interface;

pub struct State(Mutex<InnerState>);

impl std::ops::Deref for State {
    type Target = Mutex<InnerState>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

enum PluginRegistryEntry {
    Layout(Arc<dyn UntypedLayout>),
    Transformation(Arc<dyn UntypedTransformation>),
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
    plugin_registry: HashMap<PluginRegistryKey<'static>, PluginRegistryEntry>,
}

impl InnerState {
    fn new() -> Self {
        Self {
            wgpu_ctx: Arc::new(wgpu_interface::create_new_wgpu_context()),
            plugin_registry: HashMap::new(),
        }
    }

    pub fn wgpu_ctx(&self) -> Arc<WgpuContext> {
        self.wgpu_ctx.clone()
    }

    pub fn register_transformation(
        &mut self,
        transformation: Arc<dyn UntypedTransformation>,
    ) -> Result<(), CompositorError> {
        self.register(
            transformation.registry_key(),
            PluginRegistryEntry::Transformation(transformation),
        )
    }

    pub fn register_layout(
        &mut self,
        layout: Arc<dyn UntypedLayout>,
    ) -> Result<(), CompositorError> {
        self.register(layout.registry_key(), PluginRegistryEntry::Layout(layout))
    }

    fn register(
        &mut self,
        registry_key: PluginRegistryKey<'static>,
        plugin: PluginRegistryEntry,
    ) -> Result<(), CompositorError> {
        if self.plugin_registry.contains_key(&registry_key) {
            return Err(CompositorError::RegistryKeyTaken(
                registry_key.0.to_string(),
            ));
        }

        self.plugin_registry.insert(registry_key, plugin);

        Ok(())
    }
}

pub struct MockTransformation {}

impl MockTransformation {
    const NAME: &str = "mock_transformation";
}

impl CustomProcessor for MockTransformation {
    type Arg = String;

    fn registry_key() -> PluginRegistryKey<'static>
    where
        Self: Sized,
    {
        PluginRegistryKey(Self::NAME)
    }

    fn registry_key_dyn(&self) -> PluginRegistryKey<'static> {
        PluginRegistryKey(Self::NAME)
    }
}

impl Transformation for MockTransformation {
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

#[rustler::nif(schedule = "DirtyIo")]
pub fn encode_mock_transformation(
    arg: <MockTransformation as CustomProcessor>::Arg,
) -> CustomStructElixirPacket {
    unsafe { MockTransformation::encode_arg(arg) }
}
