use serde::{Deserialize, Serialize};
use epic_wallet_util::epic_core::global::ChainTypes;
use std::path::Path;
use epic_wallet_config::WalletConfig;

use crate::Error;

/// Epic Wallet Config.
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Config {
    pub wallet_dir: String,
    pub check_node_api_http_addr: String,
    pub chain: String,
    pub account: Option<String>,
    pub api_listen_port: u16,
    pub api_listen_interface: String
}

/// Implement the Config struct.
impl Config {
    pub fn from_str(json: &str) -> Result<Self, serde_json::error::Error> {
        let result = match  serde_json::from_str::<Config>(json) {
            Ok(config) => {
                config
            }, Err(err) => {
                return  Err(err);
            }
        };
        Ok(result)
    }
}

/// Create a wallet config.
pub fn create_wallet_config(config: Config) -> Result<WalletConfig, Error> {
    let chain_type = match config.chain.as_ref() {
        "mainnet" => ChainTypes::Mainnet,
        "floonet" => ChainTypes::Floonet,
        "usertesting" => ChainTypes::UserTesting,
        "automatedtesting" => ChainTypes::AutomatedTesting, // TODO: Use for tests.
        _ => ChainTypes::Floonet,
    };

    let api_secret_path = config.wallet_dir.clone() + "/.api_secret";
    let api_listen_port = config.api_listen_port;

    Ok(WalletConfig {
        chain_type: Some(chain_type),
        api_listen_interface: config.api_listen_interface,
        api_listen_port,
        owner_api_listen_port: Some(WalletConfig::default_owner_api_listen_port()),
        owner_api_interface: Some(WalletConfig::default_owner_api_interface()),
        api_secret_path: None,
        node_api_secret_path: if Path::new(&api_secret_path).exists() {
            Some(api_secret_path)
        } else {
            None
        },
        check_node_api_http_addr: config.check_node_api_http_addr,
        data_file_dir: config.wallet_dir,
        tls_certificate_file: None,
        tls_certificate_key: None,
        dark_background_color_scheme: Some(true),
        keybase_notify_ttl: Some(1440),
        no_commit_cache: Some(false),
        owner_api_include_foreign: Some(false),
    })
}
