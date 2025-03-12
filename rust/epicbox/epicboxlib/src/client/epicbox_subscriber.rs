use crate::error::Result;
use crate::client::EpicboxSubscriptionHandler;

pub trait EpicboxSubscriber {
    fn subscribe(&mut self, handler: Box<EpicboxSubscriptionHandler + Send>) -> Result<()>;
    fn unsubscribe(&self);
    fn is_running(&self) -> bool;
}
