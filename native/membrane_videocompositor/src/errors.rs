use thiserror::Error;

#[derive(Debug, Error)]
pub enum CompositorError {
    #[error("function not implemented")]
    NotImplemented,
    #[error("bad video index: {0}")]
    BadVideoIndex(usize),
    #[error("bad framerate")]
    BadFramerate,
}

impl rustler::Encoder for CompositorError {
    fn encode<'a>(&self, env: rustler::Env<'a>) -> rustler::Term<'a> {
        match self {
            CompositorError::NotImplemented => {
                rustler::Atom::from_str(env, "function_not_implemented")
                    .unwrap()
                    .encode(env)
            }
            CompositorError::BadVideoIndex(idx) => (
                rustler::Atom::from_str(env, "bad_video_index").unwrap(),
                *idx,
            )
                .encode(env),
            CompositorError::BadFramerate => rustler::Atom::from_str(env, "bad_framerate")
                .unwrap()
                .encode(env),
        }
    }
}

impl From<CompositorError> for rustler::Error {
    fn from(err: CompositorError) -> Self {
        Self::Term(Box::new(err))
    }
}
