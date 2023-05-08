use std::{any::Any, sync::Arc};

use crate::plugins::{layout::UntypedLayout, transformation::UntypedTransformation};

pub struct ElixirTypePacket {
    pointer: (usize, usize),
}

impl ElixirTypePacket {
    pub fn encode<T: 'static>(payload: T) -> ElixirTypePacket {
        let payload: Arc<dyn Any> = Arc::new(payload);
        let pointer: (usize, usize) = unsafe { std::mem::transmute(payload) };

        ElixirTypePacket { pointer }
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

impl<'a> rustler::Decoder<'a> for ElixirTypePacket {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let pointer: (usize, usize) = rustler::Decoder::decode(term)?;
        Ok(Self { pointer })
    }
}

impl rustler::Encoder for ElixirTypePacket {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        self.pointer.encode(env)
    }
}

pub struct ElixirTransformationPacket {
    pointer: (usize, usize),
}

impl ElixirTransformationPacket {
    pub fn encode(payload: impl UntypedTransformation) -> Self {
        let payload: Arc<dyn UntypedTransformation> = Arc::new(payload);
        let pointer: (usize, usize) = unsafe { std::mem::transmute(payload) };
        Self { pointer }
    }

    /// # Safety
    /// The caller must ensure that all of the following conditions are met:
    ///  - The packet must have been encoded in the same address space as the call site
    ///  - The packet must not have been cloned or duplicated in any way in elixir
    ///  - The call site must have been compiled with the same compiler as the encoding site
    pub unsafe fn decode(self) -> Arc<dyn UntypedTransformation> {
        unsafe { std::mem::transmute(self.pointer) }
    }
}

impl<'a> rustler::Decoder<'a> for ElixirTransformationPacket {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let pointer = rustler::Decoder::decode(term)?;
        Ok(Self { pointer })
    }
}

impl rustler::Encoder for ElixirTransformationPacket {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        self.pointer.encode(env)
    }
}

pub struct ElixirLayoutPacket {
    pointer: (usize, usize),
}

impl ElixirLayoutPacket {
    pub fn encode(payload: impl UntypedLayout) -> Self {
        let payload: Arc<dyn UntypedLayout> = Arc::new(payload);
        let pointer: (usize, usize) = unsafe { std::mem::transmute(payload) };
        Self { pointer }
    }

    /// # Safety
    /// The caller must ensure that all of the following conditions are met:
    ///  - The packet must have been encoded in the same address space as the call site
    ///  - The packet must not have been cloned or duplicated in any way in elixir
    ///  - The call site must have been compiled with the same compiler as the encoding site
    pub unsafe fn decode(self) -> Arc<dyn UntypedLayout> {
        unsafe { std::mem::transmute(self.pointer) }
    }
}

impl<'a> rustler::Decoder<'a> for ElixirLayoutPacket {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let pointer = rustler::Decoder::decode(term)?;
        Ok(Self { pointer })
    }
}

impl rustler::Encoder for ElixirLayoutPacket {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        self.pointer.encode(env)
    }
}
