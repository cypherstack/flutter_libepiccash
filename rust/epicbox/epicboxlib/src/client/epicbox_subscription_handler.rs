use crate::client::CloseReason;
use crate::types::{EpicboxAddress, Slate, TxProof};

pub trait EpicboxSubscriptionHandler: Send {
    fn on_open(&self);
    fn on_slate(&self, from: &EpicboxAddress, slate: &mut Slate, proof: Option<&mut TxProof>);
    fn on_close(&self, result: CloseReason);
    fn on_dropped(&self);
    fn on_reestablished(&self);
}
