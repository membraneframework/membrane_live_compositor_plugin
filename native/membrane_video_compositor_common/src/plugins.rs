use crate::elixir_transfer::CustomStructElixirPacket;

pub mod layout;
pub mod transformation;

#[derive(Debug, PartialEq, Eq, Hash)]
pub struct PluginRegistryKey<'a>(pub &'a str);

// Question for the reviewers: What should this trait be named? I don't like this name.
pub trait CustomProcessor: Send + Sync + 'static {
    type Arg: Send + 'static;

    /// Should return the same thing as `registry_key_dyn`
    fn registry_key() -> PluginRegistryKey<'static>
    where
        Self: Sized;

    /// Should return the same thing as `registry_key`
    fn registry_key_dyn(&self) -> PluginRegistryKey<'static>;

    /// # Safety
    /// Carries the same contract as [CustomStructElixirPacket::encode]
    unsafe fn encode_arg(arg: Self::Arg) -> CustomStructElixirPacket
    where
        Self: Sized,
    {
        unsafe { CustomStructElixirPacket::encode(arg, Self::registry_key()) }
    }
}
