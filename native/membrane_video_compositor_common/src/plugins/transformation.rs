use std::{any::Any, sync::Arc};

use crate::WgpuCtx;

// NOTE: Send + Sync is necessary to store these in the compositor's state later.
//       'static is necessary for sending across elixir
/// # Examples
/// initialization might look like this:
/// ```no_run
/// # use std::sync::Arc;
/// # use membrane_video_compositor_common::WgpuCtx;
/// use membrane_video_compositor_common::elixir_transfer::{StructElixirPacket, TransformationElixirPacket};
/// use membrane_video_compositor_common::plugins::transformation::Transformation;
/// # struct CustomTransformation{}
/// # struct CustomTransformationArg{}
/// # impl Transformation for CustomTransformation {
/// #     type Arg = CustomTransformationArg;
/// #     
/// #     fn name(&self) -> &'static str {
/// #         "custom transformation"
/// #     }
/// #
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
pub trait Transformation: Send + Sync + 'static {
    type Arg: Send + 'static;

    fn name(&self) -> &'static str;
    fn do_stuff(&self, arg: &Self::Arg);

    fn new(ctx: Arc<WgpuCtx>) -> Self
    where
        Self: Sized;
}

pub trait UntypedTransformation: Send + Sync + 'static {
    fn name(&self) -> &'static str;
    fn do_stuff(&self, arg: &dyn Any);
}

impl<T: Transformation> UntypedTransformation for T {
    fn name(&self) -> &'static str {
        self.name()
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
