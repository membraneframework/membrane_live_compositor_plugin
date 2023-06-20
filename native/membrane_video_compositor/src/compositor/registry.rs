use std::{collections::HashMap, sync::Arc};

use membrane_video_compositor_common::plugins::{
    layout::UntypedLayout, transformation::UntypedTransformation, PluginRegistryKey,
};

pub enum PluginRegistryEntry {
    Layout(Arc<dyn UntypedLayout>),
    Transformation(Arc<dyn UntypedTransformation>),
}

#[derive(Debug, thiserror::Error)]
pub enum PluginRegistryError {
    #[error("Tried to register a transformation or layout with registry key \"{0}\". This registry key is already taken.")]
    KeyAlreadyTaken(String),

    #[error("Tried to lookup an entry with an unregistered key: {0}")]
    EntryNotFound(String),
}

type Result<T> = std::result::Result<T, PluginRegistryError>;

#[derive(Default)]
pub struct PluginRegistry {
    registry: HashMap<PluginRegistryKey<'static>, PluginRegistryEntry>,
}

impl PluginRegistry {
    pub fn new() -> Self {
        Self {
            registry: HashMap::new(),
        }
    }

    pub fn register(
        &mut self,
        key: PluginRegistryKey<'static>,
        entry: PluginRegistryEntry,
    ) -> Result<()> {
        if self.registry.contains_key(&key) {
            return Err(PluginRegistryError::KeyAlreadyTaken(key.0.into()));
        }

        self.registry.insert(key, entry);

        Ok(())
    }

    #[allow(dead_code)] // NOTE: this is for now, until we actually start using this
    pub fn get<'a>(&'a self, key: &PluginRegistryKey<'a>) -> Result<&PluginRegistryEntry> {
        if let Some(v) = self.registry.get(key) {
            Ok(v)
        } else {
            Err(PluginRegistryError::EntryNotFound(key.0.to_string()))
        }
    }
}
