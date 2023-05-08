use std::any::Any;

// TODO: is Send + Sync + 'static necessary? is composing possible while using it?
pub trait Transformation: Send + Sync + 'static {
    type Arg: Send + Sync + 'static;

    fn name(&self) -> &'static str;
    fn do_stuff(&self, arg: &Self::Arg);
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
        self.do_stuff(arg.downcast_ref().unwrap())
    }
}
