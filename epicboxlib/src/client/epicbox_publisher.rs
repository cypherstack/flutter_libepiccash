use crate::error::Result;
use crate::types::{EpicboxAddress, Slate};

pub trait EpicboxPublisher {
    fn post_slate(&self, slate: &Slate, to: &EpicboxAddress) -> Result<()>;
}
