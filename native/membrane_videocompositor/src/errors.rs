use thiserror::Error;

#[derive(Debug, Error)]
pub enum CompositorError {
    #[error("function not implemented")]
    NotImplemented,
    #[error("bad video index: {0}")]
    BadVideoIndex(usize),
    #[error("bad framerate")]
    BadFramerate,
    #[error("unsupported pixel format")]
    UnsupportedPixelFormat,
    #[error("bad video resolution: {0}x{1}")]
    BadVideoResolution(u32, u32),
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
            CompositorError::UnsupportedPixelFormat => {
                rustler::Atom::from_str(env, "unsupported_pixel_format")
                    .unwrap()
                    .encode(env)
            }
            CompositorError::BadVideoResolution(_, _) => {
                rustler::Atom::from_str(env, "bad_video_resolution")
                    .unwrap()
                    .encode(env)
            }
        }
    }
}

impl From<CompositorError> for rustler::Error {
    fn from(err: CompositorError) -> Self {
        Self::Term(Box::new(err))
    }
}
