use std::{any::Any, marker::PhantomData, sync::Arc};

use crate::plugins::{layout::UntypedLayout, transformation::UntypedTransformation};

pub struct ElixirCustomStructPacket {
    pointer: (usize, usize),
}

/// This struct is meant for encoding and transferring structs defined and used only in the plugins
/// (i.e. unknown during the compilation of the compositor)
impl ElixirCustomStructPacket {
    pub fn encode<T: Send + 'static>(payload: T) -> ElixirCustomStructPacket {
        let payload: Arc<dyn Any> = Arc::new(payload);
        let pointer = unsafe { std::mem::transmute(payload) };

        ElixirCustomStructPacket { pointer }
    }

    /// # Safety
    /// The caller must ensure that all of the following conditions are met:
    ///  - The packet must have been encoded in the same address space as the call site
    ///  - The packet must have been encoded in a crate compiled in the same compilation as the call site
    ///  - This method can only be called **once** per packet's content, i.e. You cannot copy
    ///    this struct in elixir and pass it to two separate rust functions that would decode it twice
    pub unsafe fn decode(self) -> Arc<dyn Any> {
        let payload: Arc<dyn Any> = unsafe { std::mem::transmute(self.pointer) };

        payload
    }
}

impl<'a> rustler::Decoder<'a> for ElixirCustomStructPacket {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let pointer = rustler::Decoder::decode(term)?;
        Ok(Self { pointer })
    }
}

impl rustler::Encoder for ElixirCustomStructPacket {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        self.pointer.encode(env)
    }
}

/// This struct is meant for encoding and transferring structs used both in the compositor and in the plugins
pub struct ElixirStructPacket<T: Send + 'static> {
    pointer: usize,
    _phantom: PhantomData<T>,
}

impl<T: Send + 'static> ElixirStructPacket<T> {
    pub fn encode(payload: T) -> Self {
        let payload = Arc::new(payload);
        let pointer = unsafe { std::mem::transmute(payload) };
        Self {
            pointer,
            _phantom: PhantomData,
        }
    }

    /// # Safety
    /// The caller must ensure that all of the following conditions are met:
    ///  - The packet must have been encoded in the same address space as the call site
    ///  - The packet must have been encoded in a crate compiled with the same compiler as the call site
    ///  - This method can only be called **once** per packet's content, i.e. You cannot copy
    ///    this struct in elixir and pass it to two separate rust functions that would decode it twice
    ///  - The generic parameter T is correct, i.e. the same one used when encoding the packet
    pub unsafe fn decode(self) -> Arc<T> {
        unsafe { std::mem::transmute(self.pointer) }
    }
}

impl<'a, T: Send + 'static> rustler::Decoder<'a> for ElixirStructPacket<T> {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let pointer = term.decode()?;
        Ok(Self {
            pointer,
            _phantom: PhantomData,
        })
    }
}

impl<T: Send + 'static> rustler::Encoder for ElixirStructPacket<T> {
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
            pub fn encode(payload: impl $trait + Send) -> Self {
                let payload: ::std::sync::Arc<dyn $trait> = ::std::sync::Arc::new(payload);
                let pointer = unsafe { ::std::mem::transmute(payload) };
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
