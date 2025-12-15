use std::sync::Arc;
use anyhow::anyhow;
use ffi_helpers::{export_task, Task};
use ffi_helpers::task::CancellationToken;
use epic_util::Mutex;
use epic_util::secp::SecretKey;
use epic_wallet_config::{EpicboxConfig, TorConfig};
use epic_wallet_impls::EpicboxListenChannel;
use std::sync::atomic::AtomicBool;
use std::sync::Arc as StdArc;
use serde::Deserialize;

use crate::wallet::Wallet;

/// Listener task.
#[derive(Debug, Clone)]
pub struct Listener {
    pub wallet_ptr_str: String,
    // pub wallet_data: (i64, Option<SecretKey>),
    pub epicbox_config: String
}

/// Spawn a listener task.
impl Task for Listener {
    type Output = usize;

    fn run(&self, cancel_tok: &CancellationToken) -> Result<Self::Output, anyhow::Error> {
        let mut spins = 0;

        let wallet_data_str = &self.wallet_ptr_str;
        let (wlt, sek_key) = parse_wallet_data(wallet_data_str)?;

        // let wallet_data = &self.wallet_data;
        // let wlt = wallet_data.clone().0;
        unsafe {
            let epicbox_conf = serde_json::from_str::<EpicboxConfig>(&self.epicbox_config.as_str()).unwrap();
            // let wallet_data = &self.wallet_data;
            // let wlt = wallet_data.0;
            // let sek_key = wallet_data.clone().1;
            crate::ensure_wallet!(wlt, wallet);
            while !cancel_tok.cancelled() {
                let listener = EpicboxListenChannel::new().unwrap();
                let mut reconnections = 0;
                listener.listen(
                    wallet.clone(),
                    Arc::new(Mutex::new(sek_key.clone())),
                    epicbox_conf.clone(),
                    &mut reconnections,
                    StdArc::new(AtomicBool::new(false)),
                    TorConfig::default(),
                ).expect("TODO: Error Listening on Epicbox");
                spins += 1;
            }
        }
        Ok(spins)
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

#[derive(Deserialize)]
struct WalletData {
    wallet_ptr: i64,
    #[serde(deserialize_with = "deserialize_secret_key")]
    keychain_mask: Option<SecretKey>,
}

fn deserialize_secret_key<'de, D>(
    deserializer: D,
) -> Result<Option<SecretKey>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let opt = Option::<String>::deserialize(deserializer)?;
    match opt {
        Some(hex_str) => {
            let bytes = hex::decode(hex_str).map_err(serde::de::Error::custom)?;
            let secp = epic_util::secp::Secp256k1::new();
            SecretKey::from_slice(&secp, bytes.as_slice())
                .map(Some)
                .map_err(serde::de::Error::custom)
        }
        None => Ok(None),
    }
}

fn parse_wallet_data(wallet_data_str: &str) -> Result<(i64, Option<SecretKey>), anyhow::Error> {
    serde_json::from_str::<WalletData>(wallet_data_str)
        .map(|d| (d.wallet_ptr, d.keychain_mask))
        .or_else(|map_err| {
            serde_json::from_str::<(i64, Option<SecretKey>)>(wallet_data_str)
                .map(|t| (t.0, t.1))
                .map_err(|tuple_err| {
                    anyhow!(
                        "Failed to parse wallet data (map err: {map_err}; tuple err: {tuple_err})"
                    )
                })
        })
}
