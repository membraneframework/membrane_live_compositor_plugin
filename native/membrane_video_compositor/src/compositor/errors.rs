#[derive(Debug, thiserror::Error)]
pub enum CompositorError {
    #[error("Plugin registry error")]
    PluginRegistryError(#[from] super::registry::PluginRegistryError),
}

mod atoms {
    rustler::atoms! {
        plugin_registry_error,
    }
}

impl rustler::Encoder for CompositorError {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        match self {
            CompositorError::PluginRegistryError(err) => {
                (atoms::plugin_registry_error(), err.to_string()).encode(env)
            }
        }
    }
}

impl From<CompositorError> for rustler::Error {
    fn from(value: CompositorError) -> Self {
        Self::Term(Box::new(value))
    }
}
