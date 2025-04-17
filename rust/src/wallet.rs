use std::sync::Arc;
use serde_derive::{Deserialize, Serialize};
use stack_epic_keychain::ExtKeychain;
use stack_epic_util::{Mutex, ZeroingString};
use stack_epic_util::file::get_first_line;
use stack_epic_util::secp::{PublicKey, Secp256k1, SecretKey};
use stack_epic_wallet_api::Owner;
use stack_epic_wallet_config::{EpicboxConfig, WalletConfig};
use stack_epic_wallet_impls::{DefaultLCProvider, HTTPNodeClient};
use stack_epic_wallet_libwallet::{address, scan, wallet_lock, AddressType, EpicboxAddress, Error, InitTxArgs, InitTxSendArgs, WalletInst};
use stack_epic_wallet_libwallet::api_impl::owner;
use stack_epic_wallet_libwallet::Slate;
use uuid::Uuid;
use crate::config::{create_wallet_config, Config};
use crate::EpicWalletControllerError;
use stack_epic_wallet_libwallet::Address;
use stack_epic_wallet_libwallet::WalletLCProvider;
use stack_epic_wallet_libwallet::NodeClient;
use stack_epic_keychain::Keychain;
use stack_epic_wallet_impls::DefaultWalletImpl;
use std::cmp::Ordering;

/// Wallet type.
pub type Wallet = Arc<
    Mutex<
        Box<
            dyn WalletInst<
                'static,
                DefaultLCProvider<'static, HTTPNodeClient, ExtKeychain>,
                HTTPNodeClient,
                ExtKeychain,
            >,
        >,
    >,
>;

/// Wallet information.
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct WalletInfoFormatted {
    pub last_confirmed_height: u64,
    pub minimum_confirmations: u64,
    pub total: f64,
    pub amount_awaiting_finalization: f64,
    pub amount_awaiting_confirmation: f64,
    pub amount_immature: f64,
    pub amount_currently_spendable: f64,
    pub amount_locked: f64,
}

/// Strategy for transaction.
#[derive(Serialize, Deserialize)]
struct Strategy {
    selection_strategy_is_use_all: bool,
    total: u64,
    fee: u64,
}

/// Get transaction strategies.
pub fn tx_strategies(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    amount: u64,
    minimum_confirmations: u64,
) -> Result<String, Error> {
    let mut result = vec![];
    wallet_lock!(wallet, w);

    let args = InitTxArgs {
        src_acct_name: None,
        amount,
        minimum_confirmations,
        max_outputs: 500,
        num_change_outputs: 1,
        estimate_only: Some(true),
        message: None,
        ..Default::default()
    };

    match owner::init_send_tx(&mut **w, keychain_mask.as_ref(), args, true) {
        Ok(slate) => {
            result.push(Strategy {
                selection_strategy_is_use_all: false,
                total: slate.amount,
                fee: slate.fee,

            });
        }, Err(e) => {
            return Err(e);
        }
    }

    Ok(serde_json::to_string(&result).unwrap())
}

/// Get wallet transactions.
pub fn txs_get(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    refresh_from_node: bool,
) -> Result<String, Error> {
    let api = Owner::new(wallet.clone(), None);
    let txs = match api.retrieve_txs(
        keychain_mask.as_ref(),
        refresh_from_node,
        None,
        None
    ) {
        Ok((_, tx_entries)) => {
            tx_entries
        }, Err(e) => {
            return  Err(e);
        }
    };

    let result = txs;
    Ok(serde_json::to_string(&result).unwrap())
}

/// Initialize a transaction as sender.
///
/// Will use Epicbox for tx relay by default.  Override default behavior by setting return_slate.
#[allow(clippy::too_many_arguments)]
pub fn tx_create(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    amount: u64,
    minimum_confirmations: u64,
    selection_strategy_is_use_all: bool,
    epicbox_config: &str,
    address: &str,
    note: &str,
    return_slate: Option<bool>,
) -> Result<String, Error> {
    let return_slate = return_slate.unwrap_or(false);

    let owner_api = Owner::new(wallet.clone(), None);

    // Only set send‑args if we want the wallet to relay via Epicbox.
    let send_args = if return_slate {
        None
    } else {
        Some(InitTxSendArgs {
            method: "epicbox".into(),
            dest: address.into(),
            finalize: false,
            post_tx: false,
            fluff: false,
        })
    };

    let args = InitTxArgs {
        src_acct_name: Some("default".into()),
        amount,
        minimum_confirmations,
        max_outputs: 500,
        num_change_outputs: 1,
        selection_strategy_is_use_all,
        send_args,
        message: Some(note.into()),
        ..Default::default()
    };

    // Create the transaction.
    let slate: Slate = owner_api.init_send_tx(keychain_mask.as_ref(), args)?;

    // Fetch tx‑log entries.
    //
    // We can use type to determine if we should finalize or receive tx.
    let (_, tx_entries) = owner_api.retrieve_txs(
        keychain_mask.as_ref(),
        false,
        None,
        Some(slate.id),
    )?;

    let empty_json = r#"{"slate_msg": ""}"#;
    let tx_entries_json = serde_json::to_string(&tx_entries)
        .map_err(|e| Error::from(EpicWalletControllerError::GenericError(
            e.to_string(),
        )))?;

    let slate_json = serde_json::to_string(&slate)
        .map_err(|e| Error::from(EpicWalletControllerError::GenericError(
            e.to_string(),
        )))?;

    let response = (tx_entries_json, slate_json, String::new());

    let response_json = serde_json::to_string(&response)
        .map_err(|e| Error::from(EpicWalletControllerError::GenericError(
            e.to_string(),
        )))?;

    Ok(response_json)
}

/// Cancel a transaction by ID.
pub fn tx_cancel(wallet: &Wallet, keychain_mask: Option<SecretKey>, tx_slate_id: Uuid) -> Result<String, Error> {
    let api = Owner::new(wallet.clone(), None);
    match  api.cancel_tx(keychain_mask.as_ref(), None, Some(tx_slate_id)) {
        Ok(_) => {
            Ok("cancelled".to_owned())
        },Err(e) => {
            return Err(e);
        }
    }
}

/// Get a transaction by slate ID.
pub fn tx_get(wallet: &Wallet, refresh_from_node: bool, tx_slate_id: &str) -> Result<String, Error> {
    let api = Owner::new(wallet.clone(), None);
    let uuid = Uuid::parse_str(tx_slate_id).map_err(|e| EpicWalletControllerError::GenericError(e.to_string())).unwrap();
    let txs = api.retrieve_txs(None, refresh_from_node, None, Some(uuid)).unwrap();
    Ok(serde_json::to_string(&txs.1).unwrap())
}

/// Convert decimal to nano.
pub fn convert_deci_to_nano(amount: f64) -> u64 {
    let base_nano = 100000000;
    let nano = amount * base_nano as f64;
    nano as u64
}

/// Convert nano to decimal.
pub fn nano_to_deci(amount: u64) -> f64 {
    let base_nano = 100000000;
    let decimal = amount as f64 / base_nano as f64;
    decimal
}

/// Open a wallet.
pub fn open_wallet(config_json: &str, password: &str) -> Result<(Wallet, Option<SecretKey>), Error> {
    let config = match Config::from_str(&config_json.to_string()) {
        Ok(config) => {
            config
        }, Err(_e) => {
            return Err(Error::from(EpicWalletControllerError::GenericError(format!(
                "{}",
                "Unable to get wallet config"
            ))))
        }
    };
    let wallet = match get_wallet(&config) {
        Ok(wllet) => {
            wllet
        }
        Err(err) => {
            return  Err(err);
        }
    };
    let mut secret_key = None;
    let mut opened = false;
    {
        let mut wallet_lock = wallet.lock();
        let lc = match wallet_lock.lc_provider() {
            Ok(lc_provider) => {
                lc_provider
            }
            Err(err) => {
                return  Err(err);
            }
        };
        if let Ok(exists_wallet) = lc.wallet_exists(None) {
            if exists_wallet {
                let temp = match lc.open_wallet(
                    None,
                    ZeroingString::from(password),
                    true,
                    false) {
                    Ok(tmp_key) => {
                        tmp_key
                    }
                    Err(err) => {
                        return Err(err);
                    }
                };
                secret_key = temp;
                let wallet_inst = match lc.wallet_inst() {
                    Ok(wallet_backend) => {
                        wallet_backend
                    }
                    Err(err) => {
                        return Err(err);
                    }
                };
                if let Some(account) = config.account {
                    match wallet_inst.set_parent_key_id_by_name(&account) {
                        Ok(_) => {
                            ()
                        }
                        Err(err) => {
                            return  Err(err);
                        }
                    }
                    opened = true;
                }
            }
        }
    }
    if opened {
        Ok((wallet, secret_key))
    } else {
        Err(Error::from(EpicWalletControllerError::WalletSeedDoesntExist))
    }
}

/// Close a wallet.
pub fn close_wallet(wallet: &Wallet) -> Result<String, Error> {
    let mut wallet_lock = wallet.lock();
    let lc = wallet_lock.lc_provider()?;
    match lc.wallet_exists(None)? {
        true => {
            lc.close_wallet(None)?
        }
        false => {
            return Err(
                Error::from(EpicWalletControllerError::WalletSeedDoesntExist)
            );
        }
    }
    Ok("Wallet has been closed".to_owned())
}

/// Validate an address.
pub fn validate_address(str_address: &str) -> bool {
    match EpicboxAddress::from_str(str_address) {
        Ok(addr) => {
            if addr.address_type() == AddressType::Epicbox {
                return true;
            }
            false
        }
        Err(_) => {
            false
        }
    }
}

/// Delete a wallet.
pub fn delete_wallet(config: Config) -> Result<String, Error> {
    let mut result = String::from("");
    // get wallet object in order to use class methods
    let wallet = match get_wallet(&config) {
        Ok(wllet) => {
            wllet
        }
        Err(e) => {
            return  Err(e);
        }
    };
    //First close the wallet
    if let Ok(_) = close_wallet(&wallet) {
        let api = Owner::new(wallet.clone(), None);
        match api.delete_wallet(None) {
            Ok(_) => {
                result.push_str("deleted");
            }
            Err(err) => {
                return  Err(err);
            }
        };
    } else {
        return Err(
            Error::from(EpicWalletControllerError::GenericError(format!("{}", "Error closing wallet")))
        );
    }
    Ok(result)
}

/// Send a transaction via HTTP.
pub fn tx_send_http(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    selection_strategy_is_use_all: bool,
    minimum_confirmations: u64,
    message: &str,
    amount: u64,
    address: &str,
) -> Result<String, Error>{
    let api = Owner::new(wallet.clone(), None);
    let init_send_args = InitTxSendArgs {
        method: "http".to_string(),
        dest: address.to_string(),
        finalize: true,
        post_tx: true,
        fluff: true
    };

    let args = InitTxArgs {
        src_acct_name: Some("default".to_string()),
        amount,
        minimum_confirmations,
        max_outputs: 500,
        num_change_outputs: 1,
        selection_strategy_is_use_all,
        message: Some(message.to_string()),
        send_args: Some(init_send_args),
        ..Default::default()
    };

    match api.init_send_tx(keychain_mask.as_ref(), args) {
        Ok(slate) => {
            println!("{}", "CREATE_TX_SUCCESS");
            //Get transaction for slate, for UI display
            let txs = match api.retrieve_txs(
                keychain_mask.as_ref(),
                false,
                None,
                Some(slate.id)
            ) {
                Ok(txs_result) => {
                    txs_result
                }, Err(e) => {
                    return Err(e);
                }
            };

            let tx_data = (
                serde_json::to_string(&txs.1).unwrap(),
                serde_json::to_string(&slate).unwrap()
            );
            let str_tx_data = serde_json::to_string(&tx_data).unwrap();
            Ok(str_tx_data)
        } Err(err) => {
            println!("CREATE_TX_ERROR_IN_HTTP_SEND {}", err.to_string());
            return  Err(err);
        }
    }
}

/// Create a wallet.
pub fn create_wallet(config: &str, phrase: &str, password: &str, name: &str) -> Result<String, Error> {
    let wallet_pass = ZeroingString::from(password);
    let wallet_config = match Config::from_str(&config) {
        Ok(config) => {
            config
        }, Err(e) => {
            return  Err(Error::from(EpicWalletControllerError::GenericError(format!(
                "Error getting wallet config: {}",
                e.to_string()
            ))));
        }
    };

    let wallet = match get_wallet(&wallet_config) {
        Ok(wllet) => {
            wllet
        }
        Err(e) => {
            return  Err(e);
        }
    };
    let mut wallet_lock = wallet.lock();
    let lc = match wallet_lock.lc_provider() {
        Ok(wallet_lc) => {
            wallet_lc
        }
        Err(e) => {
            return  Err(e);
        }
    };
    let rec_phrase = ZeroingString::from(phrase);
    let result = match lc.create_wallet(
        Some(name),
        Some(rec_phrase),
        32,
        wallet_pass,
        false,
    ) {
        Ok(_) => {
            "".to_string()
        },
        Err(e) => {
            e.to_string()
        },
    };
    Ok(result)
}

/// Get a wallet's secret key pair.
pub fn get_wallet_secret_key_pair(
    wallet: &Wallet, keychain_mask: Option<SecretKey>, index: u32
) -> Result<(SecretKey, PublicKey), Error>{
    let parent_key_id = {
        wallet_lock!(wallet, w);
        w.parent_key_id().clone()
    };
    wallet_lock!(wallet, w);

    let k = match w.keychain(keychain_mask.as_ref()) {
        Ok(keychain) => {
            keychain
        }
        Err(err) => {
            return  Err(err);
        }
    };
    let s = Secp256k1::new();
    let sec_key = match address::address_from_derivation_path(
        &k, &parent_key_id, index
    ) {
        Ok(s_key) => {
            s_key
        }
        Err(err) => {
            return Err(err);
        }
    };
    let pub_key = match PublicKey::from_secret_key(&s, &sec_key) {
        Ok(p_key) => {
            p_key
        }
        Err(err) => {
            return Err(Error::from(
                EpicWalletControllerError::GenericError(
                    format!("{}", err.to_string())
                )
            ));
        }
    };

    Ok((sec_key, pub_key))
}

/// Get a summary of a wallet's state.
pub fn get_wallet_info(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    refresh_from_node: bool,
    min_confirmations: u64
) -> Result<WalletInfoFormatted, Error> {
    println!(">> get_wallet_info called with refresh_from_node={refresh_from_node}, min_confirmations={min_confirmations}");
    let api = Owner::new(wallet.clone(), None);

    match api.retrieve_summary_info(keychain_mask.as_ref(), refresh_from_node, min_confirmations) {
        Ok((_, wallet_summary)) => {
            println!(">> raw wallet_summary: {wallet_summary:?}");
            Ok(WalletInfoFormatted {
                last_confirmed_height: wallet_summary.last_confirmed_height,
                minimum_confirmations: wallet_summary.minimum_confirmations,
                total: nano_to_deci(wallet_summary.total),
                amount_awaiting_finalization: nano_to_deci(wallet_summary.amount_awaiting_finalization),
                amount_awaiting_confirmation: nano_to_deci(wallet_summary.amount_awaiting_confirmation),
                amount_immature: nano_to_deci(wallet_summary.amount_immature),
                amount_currently_spendable: nano_to_deci(wallet_summary.amount_currently_spendable),
                amount_locked: nano_to_deci(wallet_summary.amount_locked)
            })
        }, Err(e) => {
            println!(">> get_wallet_info error: {e}");
            Err(e)
        }
    }
}

/// Recover a wallet from a mnemonic.
pub fn recover_from_mnemonic(mnemonic: &str, password: &str, config: &Config, name: &str) -> Result<(), Error> {
    let wallet = match get_wallet(&config) {
        Ok(conf) => {
            conf
        }
        Err(e) => {
            return  Err(e);
        }
    };
    let mut w_lock = wallet.lock();
    let lc = match w_lock.lc_provider() {
        Ok(wallet_lc) => {
            wallet_lc
        }
        Err(e) => {
            return  Err(e);
        }
    };

    // First check if wallet seed directory exists, if not create.
    if let Ok(exists_wallet_seed) = lc.wallet_exists(None) {
        return if exists_wallet_seed {
            match lc.recover_from_mnemonic(
                ZeroingString::from(mnemonic), ZeroingString::from(password)
            ) {
                Ok(_) => {
                    Ok(())
                }
                Err(e) => {
                    Err(e)
                }
            }
        } else {
            match lc.create_wallet(
                Some(&name),
                Some(ZeroingString::from(mnemonic)),
                32,
                ZeroingString::from(password),
                false,
            ) {
                Ok(_) => {
                    Ok(())
                }
                Err(e) => {
                    Err(e)
                }
            }
        }
    }
    Ok(())
}

/// Get a wallet.
pub fn get_wallet(config: &Config) -> Result<Wallet, Error> {
    let wallet_config = match create_wallet_config(config.clone()) {
        Ok(conf) => {
            conf
        } Err(e) => {
            return Err(e);
        }
    };
    let node_api_secret = get_first_line(wallet_config.node_api_secret_path.clone());
    let node_client = HTTPNodeClient::new(&wallet_config.check_node_api_http_addr, node_api_secret).unwrap();
    let wallet =  match inst_wallet::<
        DefaultLCProvider<HTTPNodeClient, ExtKeychain>,
        HTTPNodeClient,
        ExtKeychain,
    >(wallet_config.clone(), node_client) {
        Ok(wallet_inst) => {
            wallet_inst
        }
        Err(e) => {
            return  Err(e);
        }
    };
    return Ok(wallet);
}

/// Instantiate a wallet.
fn inst_wallet<L, C, K>(
    config: WalletConfig,
    node_client: C,
) -> Result<Arc<Mutex<Box<dyn WalletInst<'static, L, C, K>>>>, Error>
where
    DefaultWalletImpl<'static, C>: WalletInst<'static, L, C, K>,
    L: WalletLCProvider<'static, C, K>,
    C: NodeClient + 'static,
    K: Keychain + 'static,
{
    let mut wallet = Box::new(DefaultWalletImpl::<'static, C>::new(node_client.clone()).unwrap())
        as Box<dyn WalletInst<'static, L, C, K>>;
    let lc = match wallet.lc_provider() {
        Ok(wallet_lc) => {
            wallet_lc
        }
        Err(err) => {
            return  Err(err);
        }
    };
    match lc.set_top_level_directory(&config.data_file_dir) {
        Ok(_) => {
            ()
        }
        Err(err) => {
            return  Err(err);
        }
    };
    Ok(Arc::new(Mutex::new(wallet)))
}

/// Get the chain height.
pub fn get_chain_height(config: &str) -> Result<u64, Error> {
    let config = match Config::from_str(&config.to_string()) {
        Ok(config) => {
            config
        }, Err(_e) => {
            return Err(Error::from(EpicWalletControllerError::GenericError(format!(
                "{}",
                "Unable to get wallet config"
            ))))
        }
    };
    let wallet_config = match create_wallet_config(config.clone()) {
        Ok(wallet_conf) => {
            wallet_conf
        }
        Err(e) => {
            return  Err(e);
        }
    };
    let node_api_secret = get_first_line(wallet_config.node_api_secret_path.clone());
    let node_client = HTTPNodeClient::new(&wallet_config.check_node_api_http_addr, node_api_secret);
    let chain_tip = match node_client?.chain_height() {
        Ok(tip) => {
            tip
        }
        Err(err) => {
            return  Err(err);
        }
    };
    Ok(chain_tip.0)
}

/// Scan the wallet outputs.
pub fn wallet_scan_outputs(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    start_height: Option<u64>,
    number_of_blocks_to_scan: Option<u64>
) -> Result<String, Error> {
    let tip = {
        wallet_lock!(wallet, w);
        match w.w2n_client().get_chain_tip() {
            Ok(chain_tip) => {
                chain_tip.0
            },
            Err(_e) => {
                0
            }
        }
    };

    if tip == 0 {
        return Err(Error::from(EpicWalletControllerError::GenericError(format!(
            "{}",
            "Unable to scan, could not determine chain height"
        ))));
    }

    let start_height: u64 = match start_height {
        Some(h) => h,
        None => 1,
    };

    let number_of_blocks_to_scan: u64 = match number_of_blocks_to_scan {
        Some(h) => h,
        None => 0,
    };

    let last_block = start_height.clone() + number_of_blocks_to_scan;
    let end_height: u64 = match last_block.cmp(&tip) {
        Ordering::Less => {
            last_block
        },
        Ordering::Greater => {
            tip
        },
        Ordering::Equal => {
            last_block
        }
    };

    match scan(
        wallet.clone(),
        keychain_mask.as_ref(),
        false,
        start_height,
        end_height,
        &None,
    ) {
        Ok(info) => {
            println!("Info type: {:?}", info);

            let parent_key_id = {
                wallet_lock!(wallet, w);
                w.parent_key_id().clone()
            };

            {
                wallet_lock!(wallet, w);
                let mut batch = match w.batch(keychain_mask.as_ref()) {
                    Ok(wallet_output_batch) => {
                        wallet_output_batch
                    }
                    Err(err) => {
                        return Err(err);
                    }
                };
                match batch.save_last_confirmed_height(&parent_key_id, info.clone().height) {
                    Ok(_) => {
                        ()
                    }
                    Err(err) => {
                        return  Err(err);
                    }
                };
                match batch.commit() {
                    Ok(_) => {
                        ()
                    }
                    Err(err) => {
                        return  Err(err);
                    }
                }
            };


            let result = info.height;
            Ok(serde_json::to_string(&result).unwrap())
            // Ok(serde_json::to_string(&info).unwrap())
        }, Err(e) => {
            return  Err(e);
        }
    }
}
