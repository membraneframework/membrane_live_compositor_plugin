use std::{any::Any, sync::Arc};

use crate::WgpuContext;

use super::{PluginArgumentEncoder, PluginRegistryKey};

// NOTE: Send + Sync is necessary to store these in the compositor's state later.
//       'static is necessary for sending across elixir
pub trait Layout: PluginArgumentEncoder {
    fn do_stuff(&self, arg: &Self::Arg);
    fn new(ctx: Arc<WgpuContext>) -> Self
    where
        Self: Sized;
}

pub trait UntypedLayout: Send + Sync + 'static {
    fn registry_key(&self) -> PluginRegistryKey<'static>;
    fn do_stuff(&self, arg: &dyn Any);
}

impl<T: Layout> UntypedLayout for T {
    fn registry_key(&self) -> PluginRegistryKey<'static> {
        <Self as PluginArgumentEncoder>::registry_key()
    }

    fn do_stuff(&self, arg: &dyn Any) {
        self.do_stuff(
            arg.downcast_ref().unwrap_or_else(|| panic!(
                "in {}, expected a successful cast to user-defined Arg type. Something went seriously wrong here.",
                module_path!(),
            ))
        )
    }
}
