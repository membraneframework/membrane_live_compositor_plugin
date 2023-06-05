use std::{any::Any, sync::Arc};

use crate::WgpuContext;

// Question to the reviewers: should the example below be in the finished documentation? Should it be
//                            kept until the end of the plugins PR?
//
// Question to the reviewers, but for later: There are a couple of syntax sugar possibilities for the initialization described below.
//                                           We could have a proc macro, a macro_rules macro, or possibly even leave it as-is but
//                                           generate the boilerplate. Which one should we use?
// NOTE: Send + Sync is necessary to store these in the compositor's state later.
//       'static is necessary for sending across elixir
/// # Examples
/// initialization might look like this:
/// ```no_run
/// # use std::sync::Arc;
/// # use membrane_video_compositor_common::WgpuContext;
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
/// #     fn new(ctx: Arc<WgpuContext>) -> Self
/// #     where
/// #         Self: Sized {
/// #         Self {}
/// #     }
/// # }
///
/// #[rustler::nif]
/// fn get_transformation(ctx: StructElixirPacket<WgpuContext>) -> TransformationElixirPacket {
///     let ctx = unsafe { ctx.decode() };
///     unsafe { TransformationElixirPacket::encode(CustomTransformation::new(ctx)) }
/// }
/// ```
pub trait Transformation: Send + Sync + 'static {
    type Arg: Send + 'static;

    fn name(&self) -> &'static str;
    fn do_stuff(&self, arg: &Self::Arg);

    fn new(ctx: Arc<WgpuContext>) -> Self
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
