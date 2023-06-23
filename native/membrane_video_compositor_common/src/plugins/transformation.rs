use std::{any::Any, sync::Arc};

use crate::{plugins::PluginArgumentEncoder, texture::Texture, WgpuCtx};

use super::PluginRegistryKey;

// NOTE: Send + Sync is necessary to store these in the compositor's state later.
//       'static is necessary for sending across elixir
/// # Examples
/// initialization might look like this:
/// ```no_run
/// # use std::sync::Arc;
/// # use membrane_video_compositor_common::{WgpuCtx, wgpu, texture::Texture};
/// use membrane_video_compositor_common::elixir_transfer::{StructElixirPacket, TransformationElixirPacket};
/// use membrane_video_compositor_common::plugins::{PluginArgumentEncoder, PluginRegistryKey, transformation::Transformation};
/// # struct CustomTransformation{
/// #     ctx: Arc<WgpuCtx>
/// # }
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
/// #     type Error = ();
/// #
/// #     fn apply(&self, arg: &Self::Arg, source: &Texture, target: &Texture) -> Result<(), Self::Error> {
/// #         Ok(())
/// #     }
/// #     fn new(ctx: Arc<WgpuCtx>) -> Self
/// #     where
/// #         Self: Sized {
/// #         Self { ctx }
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
    type Error: rustler::Encoder;

    fn apply(&self, arg: &Self::Arg, source: &Texture, target: &Texture)
        -> Result<(), Self::Error>;

    fn new(ctx: Arc<WgpuCtx>) -> Self
    where
        Self: Sized;
}

pub trait UntypedTransformation: Send + Sync + 'static {
    fn registry_key(&self) -> PluginRegistryKey<'static>;
    fn apply(
        &self,
        arg: &dyn Any,
        source: &Texture,
        target: &Texture,
    ) -> Result<(), Box<dyn rustler::Encoder>>;
}

impl<T: Transformation> UntypedTransformation for T {
    fn registry_key(&self) -> PluginRegistryKey<'static> {
        <Self as PluginArgumentEncoder>::registry_key()
    }

    fn apply(
        &self,
        arg: &dyn Any,
        source: &Texture,
        target: &Texture,
    ) -> Result<(), Box<dyn rustler::Encoder>> {
        self.apply(
            arg.downcast_ref().unwrap_or_else(|| panic!(
                "in {}, expected a successful cast to user-defined Arg type. Something went seriously wrong here.", 
                module_path!()
            )),
            source,
            target
        ).map_err(|err| Box::new(err) as Box<dyn rustler::Encoder>)
    }
}
