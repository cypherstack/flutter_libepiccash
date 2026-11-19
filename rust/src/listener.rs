use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use ffi_helpers::{export_task, Task};
use ffi_helpers::task::CancellationToken;
use epic_util::Mutex;
use epic_util::secp::SecretKey;
use epic_wallet_config::{EpicboxConfig, TorConfig};
use epic_wallet_impls::EpicboxListenChannel;

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
        let tuple_wallet_data: (i64, Option<SecretKey>) =
            serde_json::from_str(&self.wallet_ptr_str)?;
        let wlt = tuple_wallet_data.0;
        let sek_key = tuple_wallet_data.1;

        unsafe {
            let epicbox_conf = serde_json::from_str::<EpicboxConfig>(&self.epicbox_config)?;

            crate::ensure_wallet!(wlt, wallet);

            if cancel_tok.cancelled() {
                return Ok(0);
            }

            let stopping = Arc::new(AtomicBool::new(false));
            let stopping_listener = stopping.clone();
            let wallet = wallet.clone();

            let listener_thread = thread::spawn(move || -> Result<(), anyhow::Error> {
                let listener = EpicboxListenChannel::new()
                    .map_err(|error| anyhow::anyhow!("Failed to create Epicbox listener: {error}"))?;
                let mut reconnections = 0;

                listener
                    .listen(
                        wallet,
                        Arc::new(Mutex::new(sek_key)),
                        epicbox_conf,
                        &mut reconnections,
                        // Must be true for the listener to process messages.
                        Arc::new(AtomicBool::new(true)),
                        TorConfig::default(),
                        stopping_listener,
                    )
                    .map_err(|error| anyhow::anyhow!("Epicbox listener error: {error}"))
            });

            while !cancel_tok.cancelled() && !listener_thread.is_finished() {
                thread::sleep(Duration::from_millis(100));
            }

            if cancel_tok.cancelled() {
                stopping.store(true, Ordering::SeqCst);
            }

            match listener_thread.join() {
                Ok(result) => result?,
                Err(_) => return Err(anyhow::anyhow!("Epicbox listener thread panicked")),
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
