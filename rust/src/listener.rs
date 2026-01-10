use std::sync::Arc;
use ffi_helpers::{export_task, Task};
use ffi_helpers::task::CancellationToken;
use epic_util::Mutex;
use epic_util::secp::SecretKey;
use epic_wallet_config::{EpicboxConfig, TorConfig};
use epic_wallet_impls::EpicboxListenChannel;
use std::sync::atomic::AtomicBool;
use std::sync::Arc as StdArc;

use crate::wallet::Wallet;

/// Listener task.
#[derive(Debug, Clone)]
pub struct Listener {
    pub wallet_ptr_str: String,
    pub epicbox_config: String
}

/// Spawn a listener task.
impl Task for Listener {
    type Output = usize;

    fn run(&self, cancel_tok: &CancellationToken) -> Result<Self::Output, anyhow::Error> {
        let wallet_data_str = &self.wallet_ptr_str;
        let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data_str).unwrap();
        let wlt = tuple_wallet_data.0;
        let sek_key = tuple_wallet_data.1;

        unsafe {
            let epicbox_conf = serde_json::from_str::<EpicboxConfig>(&self.epicbox_config.as_str()).unwrap();

            crate::ensure_wallet!(wlt, wallet);

            // Only attempt connection if not cancelled
            if !cancel_tok.cancelled() {
                let listener = EpicboxListenChannel::new().unwrap();

                let mut reconnections = 0;

                match listener.listen(
                    wallet.clone(),
                    Arc::new(Mutex::new(sek_key.clone())),
                    epicbox_conf.clone(),
                    &mut reconnections,
                    // IMPORTANT: Must be true for the listener to process messages.
                    // When false, the epicbox subscriber loop just sleeps and skips message processing.
                    StdArc::new(AtomicBool::new(true)),
                    TorConfig::default(),
                ) {
                    Ok(_) => {
                        // Graceful close (server sent Close message or clean shutdown).
                        // Do not reconnect - the caller can restart the listener if needed.
                    }
                    Err(e) => {
                        return Err(anyhow::Error::msg(format!("Epicbox listener error: {}", e)));
                    }
                }
            }
        }
        Ok(0)
    }
}

export_task! {
    Task: Listener;
    spawn: listener_spawn;
    wait: listener_wait;
    poll: listener_poll;
    cancel: listener_cancel;
    cancelled: listener_cancelled;
    handle_destroy: listener_handle_destroy;
    result_destroy: listener_result_destroy;
}
