use std::{any::Any, sync::Arc};

use crate::{plugins::PluginArgumentEncoder, WgpuCtx};

use super::PluginRegistryKey;

// NOTE: Send + Sync is necessary to store these in the compositor's state later.
//       'static is necessary for sending across elixir
/// # Examples
/// initialization might look like this:
/// ```no_run
/// # use std::sync::Arc;
/// # use membrane_video_compositor_common::WgpuCtx;
/// use membrane_video_compositor_common::elixir_transfer::{StructElixirPacket, TransformationElixirPacket};
/// use membrane_video_compositor_common::plugins::{PluginArgumentEncoder, PluginRegistryKey, transformation::Transformation};
/// # struct CustomTransformation{}
/// # struct CustomTransformationArg{}
/// #
/// # impl PluginArgumentEncoder for CustomTransformation {
/// #     type Arg = CustomTransformationArg;
/// #     fn registry_key() -> PluginRegistryKey<'static>
/// #     where
/// #         Self: Sized
/// #     {
/// #         PluginRegistryKey("custom transformation")
/// #     }
/// # }
/// #
/// # impl Transformation for CustomTransformation {
/// #     fn do_stuff(&self, arg: &Self::Arg) {}
/// #     fn new(ctx: Arc<WgpuCtx>) -> Self
/// #     where
/// #         Self: Sized {
/// #         Self {}
/// #     }
/// # }
///
/// #[rustler::nif]
/// fn get_transformation(ctx: StructElixirPacket<WgpuCtx>) -> TransformationElixirPacket {
///     let ctx = unsafe { ctx.decode() };
///     unsafe { TransformationElixirPacket::encode(CustomTransformation::new(ctx)) }
/// }
/// ```
pub trait Transformation: PluginArgumentEncoder {
    fn do_stuff(&self, arg: &Self::Arg);

    fn new(ctx: Arc<WgpuCtx>) -> Self
    where
        Self: Sized;
}

pub trait UntypedTransformation: Send + Sync + 'static {
    fn registry_key(&self) -> PluginRegistryKey<'static>;
    fn do_stuff(&self, arg: &dyn Any);
}

impl<T: Transformation> UntypedTransformation for T {
    fn registry_key(&self) -> PluginRegistryKey<'static> {
        <Self as PluginArgumentEncoder>::registry_key()
    }

    fn do_stuff(&self, arg: &dyn Any) {
        self.do_stuff(
            arg.downcast_ref().unwrap_or_else(|| panic!(
                "in {}, expected a successful cast to user-defined Arg type. Something went seriously wrong here.", 
                module_path!()
            ))
        )
    }
}
