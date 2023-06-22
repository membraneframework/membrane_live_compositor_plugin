use std::{any::Any, sync::Arc};

use crate::WgpuCtx;

// NOTE: Send + Sync is necessary to store these in the compositor's state later.
//       'static is necessary for sending across elixir
pub trait Layout: Send + Sync + 'static {
    type Arg: Send + Sync + 'static;

    fn name(&self) -> &'static str;
    fn do_stuff(&self, arg: &Self::Arg);
    fn new(ctx: Arc<WgpuCtx>) -> Self
    where
        Self: Sized;
}

pub trait UntypedLayout: Send + Sync + 'static {
    fn name(&self) -> &'static str;
    fn do_stuff(&self, arg: &dyn Any);
}

impl<T: Layout> UntypedLayout for T {
    fn name(&self) -> &'static str {
        self.name()
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
