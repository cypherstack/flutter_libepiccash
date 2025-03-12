mod epicbox_address;
mod epicbox_message;
mod epicbox_request;
mod epicbox_response;
mod tx_proof;

//pub use epic_wallet::libwallet::slate::Slate;
pub use epic_wallet_libwallet::slate::Slate;
pub use parking_lot::{Mutex, MutexGuard};
pub use std::sync::Arc;

pub use self::epicbox_address::{EpicboxAddress, EPICBOX_ADDRESS_VERSION_MAINNET, EPICBOX_ADDRESS_VERSION_TESTNET, version_bytes};
pub use self::epicbox_message::EpicboxMessage;
pub use self::epicbox_request::EpicboxRequest;
pub use self::epicbox_response::{EpicboxError, EpicboxResponse};
pub use self::tx_proof::{TxProof, ErrorKind as TxProofErrorKind};
