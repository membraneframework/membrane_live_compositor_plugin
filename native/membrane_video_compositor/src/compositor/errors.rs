#[derive(Debug, thiserror::Error)]
pub enum CompositorError {
    #[error("Tried to register a transformation or layout with registry key \"{0}\". This registry key is already taken.")]
    RegistryKeyTaken(String),
}

mod atoms {
    rustler::atoms! {
        transformation_name_taken,
        layout_name_taken,
    }
}

impl rustler::Encoder for CompositorError {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        match self {
            CompositorError::RegistryKeyTaken(name) => {
                (atoms::transformation_name_taken(), name).encode(env)
            }
        }
    }
}

impl From<CompositorError> for rustler::Error {
    fn from(value: CompositorError) -> Self {
        Self::Term(Box::new(value))
    }
}
