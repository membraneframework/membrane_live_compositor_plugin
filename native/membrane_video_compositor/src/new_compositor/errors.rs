#[derive(Debug, thiserror::Error)]
pub enum NewCompositorError {
    #[error("Tried to register a transformation called {0}. This name is already taken.")]
    TransformationNameTaken(String),

    #[error("Tried to register a layout called {0}. This name is already taken.")]
    LayoutNameTaken(String),
}

mod atoms {
    rustler::atoms! {
        transformation_name_taken,
        layout_name_taken,
    }
}

impl rustler::Encoder for NewCompositorError {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        match self {
            NewCompositorError::TransformationNameTaken(name) => {
                (atoms::transformation_name_taken(), name).encode(env)
            }
            NewCompositorError::LayoutNameTaken(name) => {
                (atoms::layout_name_taken(), name).encode(env)
            }
        }
    }
}

impl From<NewCompositorError> for rustler::Error {
    fn from(value: NewCompositorError) -> Self {
        Self::Term(Box::new(value))
    }
}
