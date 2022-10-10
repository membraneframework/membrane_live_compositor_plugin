#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("the data provided has a different length than the buffer it was supposed to be uploaded into")]
    UploadDataSizeMismatch,
    #[error("the data that was attempted to be downloaded doesn't fit in the provided buffer")]
    DownloadBufferTooSmall,
}

pub type Result<T> = std::result::Result<T, Error>;
