use std::{any::Any, sync::Arc};

use crate::plugins::{layout::UntypedLayout, transformation::UntypedTransformation};

pub struct ElixirCustomStructPacket {
    pointer: (usize, usize),
}

impl ElixirCustomStructPacket {
    pub fn encode<T: 'static>(payload: T) -> ElixirCustomStructPacket {
        let payload: Arc<dyn Any> = Arc::new(payload);
        let pointer: (usize, usize) = unsafe { std::mem::transmute(payload) };

        ElixirCustomStructPacket { pointer }
    }

    /// # Safety
    /// The caller must ensure that all of the following conditions are met:
    ///  - The packet must have been encoded in the same address space as the call site
    ///  - The packet must have been encoded in a crate compiled in the same compilation as the call site
    ///  - The packet must not have been cloned or duplicated in any way in elixir
    pub unsafe fn decode(self) -> Arc<dyn Any> {
        let payload: Arc<dyn Any> = unsafe { std::mem::transmute(self.pointer) };

        payload
    }
}

impl<'a> rustler::Decoder<'a> for ElixirCustomStructPacket {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let pointer: (usize, usize) = rustler::Decoder::decode(term)?;
        Ok(Self { pointer })
    }
}

impl rustler::Encoder for ElixirCustomStructPacket {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        self.pointer.encode(env)
    }
}

macro_rules! trait_packet {
    ($trait:ident, $struct:ident) => {
        pub struct $struct {
            pointer: (usize, usize),
        }

        impl $struct {
            pub fn encode(payload: impl $trait) -> Self {
                let payload: ::std::sync::Arc<dyn $trait> = ::std::sync::Arc::new(payload);
                let pointer: (usize, usize) = unsafe { ::std::mem::transmute(payload) };
                Self { pointer }
            }

            /// # Safety
            /// The caller must ensure that all of the following conditions are met:
            ///  - The packet must have been encoded in the same address space as the call site
            ///  - This method can only be called **once** per packet's content, i.e. You cannot copy
            ///    this struct in elixir and pass it to two separate rust functions that would decode it twice
            ///  - The call site must have been compiled with the same compiler as the encoding site
            pub unsafe fn decode(self) -> Arc<dyn $trait> {
                unsafe { ::std::mem::transmute(self.pointer) }
            }
        }

        impl<'a> ::rustler::Decoder<'a> for $struct {
            fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
                let pointer = rustler::Decoder::decode(term)?;
                Ok(Self { pointer })
            }
        }

        impl ::rustler::Encoder for $struct {
            fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
                self.pointer.encode(env)
            }
        }
    };
}

trait_packet!(UntypedTransformation, ElixirTransformationPacket);

trait_packet!(UntypedLayout, ElixirLayoutPacket);
