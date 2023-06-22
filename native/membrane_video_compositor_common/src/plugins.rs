use crate::elixir_transfer::CustomStructElixirPacket;

pub mod layout;
pub mod transformation;

#[derive(Debug, PartialEq, Eq, Hash)]
pub struct PluginRegistryKey<'a>(pub &'a str);

pub trait PluginArgumentEncoder: Send + Sync + 'static {
    type Arg: Send + 'static;

    fn registry_key() -> PluginRegistryKey<'static>
    where
        Self: Sized;

    /// # Safety
    /// Carries the same contract as [CustomStructElixirPacket::encode]
    unsafe fn encode_arg(arg: Self::Arg) -> CustomStructElixirPacket
    where
        Self: Sized,
    {
        unsafe { CustomStructElixirPacket::encode(arg, Self::registry_key()) }
    }
}
