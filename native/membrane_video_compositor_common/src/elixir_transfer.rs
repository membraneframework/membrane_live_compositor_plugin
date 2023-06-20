use std::{any::Any, marker::PhantomData, sync::Arc};

use crate::plugins::{
    layout::UntypedLayout, transformation::UntypedTransformation, PluginRegistryKey,
};

/// This struct is meant for encoding and transferring structs defined and used only in the plugins
/// (i.e. unknown during the compilation of the compositor)
pub struct CustomStructElixirPacket {
    pub recipient_registry_key: String,
    pointer: (usize, usize),
}

impl CustomStructElixirPacket {
    /// # Safety
    /// The struct created with this function has to be consumed with [CustomStructElixirPacket::decode].
    /// Not consuming it will result in memory leaks or other unfortunate side-effects
    pub unsafe fn encode<T: Send + 'static>(
        payload: T,
        recipient_key: PluginRegistryKey<'_>,
    ) -> Self {
        let payload: Arc<dyn Any> = Arc::new(payload);
        let pointer = unsafe { std::mem::transmute(payload) };

        CustomStructElixirPacket {
            recipient_registry_key: recipient_key.0.to_owned(),
            pointer,
        }
    }

    /// # Safety
    /// The caller must ensure that all of the following conditions are met:
    ///  - The packet must have been encoded in the same address space as the call site
    ///  - The packet must have been encoded in a crate compiled in the same compilation as the call site
    ///  - This method can only be called **once** per packet's content, i.e. You cannot copy
    ///    this struct in elixir and pass it to two separate rust functions that would decode it twice
    pub unsafe fn decode(self) -> DecodedCustomStructElixirPacket {
        let payload: Arc<dyn Any> = unsafe { std::mem::transmute(self.pointer) };

        DecodedCustomStructElixirPacket {
            recipient_registry_key: self.recipient_registry_key,
            payload,
        }
    }
}

impl std::fmt::Debug for CustomStructElixirPacket {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CustomStructElixirPacket")
            .field("recipient_registry_key", &self.recipient_registry_key)
            .field(
                "pointer",
                &(self.pointer.0 as *const (), self.pointer.1 as *const ()),
            )
            .finish()
    }
}

impl<'a> rustler::Decoder<'a> for CustomStructElixirPacket {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let (recipient, pointer) = rustler::Decoder::decode(term)?;
        Ok(Self {
            recipient_registry_key: recipient,
            pointer,
        })
    }
}

impl rustler::Encoder for CustomStructElixirPacket {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        (self.recipient_registry_key.clone(), self.pointer).encode(env)
    }
}

pub struct DecodedCustomStructElixirPacket {
    recipient_registry_key: String,
    pub payload: Arc<dyn Any>,
}

impl DecodedCustomStructElixirPacket {
    pub fn recipient_registry_key(&self) -> PluginRegistryKey {
        PluginRegistryKey(&self.recipient_registry_key)
    }
}

/// This struct is meant for encoding and transferring structs used both in the compositor and in the plugins
// TODO: shouldn't this be `Sync`?
pub struct StructElixirPacket<T: Send + 'static> {
    pointer: usize,
    _phantom: PhantomData<T>,
}

impl<T: Send + 'static> StructElixirPacket<T> {
    /// # Safety
    /// The struct created with this function has to be consumed with [StructElixirPacket::decode].
    /// Not consuming it will result in memory leaks or other unfortunate side-effects
    pub unsafe fn encode(payload: T) -> Self {
        let payload = Arc::new(payload);
        Self::encode_arc(payload)
    }

    /// # Safety
    /// The struct created with this function has to be consumed with [StructElixirPacket::decode].
    /// Not consuming it will result in memory leaks or other unfortunate side-effects
    pub fn encode_arc(payload: Arc<T>) -> Self {
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

impl<'a, T: Send + 'static> rustler::Decoder<'a> for StructElixirPacket<T> {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let pointer = term.decode()?;
        Ok(Self {
            pointer,
            _phantom: PhantomData,
        })
    }
}

impl<T: Send + 'static> rustler::Encoder for StructElixirPacket<T> {
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
            /// # Safety
            /// The struct created with this function has to be consumed with the decode method.
            /// Not consuming it will result in memory leaks or other unfortunate side-effects
            pub unsafe fn encode(payload: impl $trait + Send) -> Self {
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

trait_packet!(UntypedTransformation, TransformationElixirPacket);

trait_packet!(UntypedLayout, LayoutElixirPacket);
