use std::sync::Arc;
use std::sync::atomic::AtomicBool;
use serde_derive::{Deserialize, Serialize};
use epic_keychain::ExtKeychain;
use epic_util::{Mutex, ZeroingString};
use epic_util::file::get_first_line;
use epic_util::secp::{PublicKey, Secp256k1, SecretKey};
use epic_wallet_api::Owner;
use epic_wallet_config::{EpicboxConfig, WalletConfig};
use epic_wallet_impls::{DefaultLCProvider, HTTPNodeClient};
use epic_wallet_libwallet::{address, scan, wallet_lock, AddressType, EpicboxAddress, Error, InitTxArgs, InitTxSendArgs, WalletInst};
use epic_wallet_libwallet::api_impl::owner;
use uuid::Uuid;
use crate::config::{create_wallet_config, Config};
use crate::EpicWalletControllerError;
use epic_wallet_libwallet::Address;
use epic_wallet_libwallet::WalletLCProvider;
use epic_wallet_libwallet::NodeClient;
use epic_keychain::Keychain;
use epic_wallet_impls::DefaultWalletImpl;
use std::cmp::Ordering;
use std::thread;
use std::time::Duration;
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
    use std::sync::mpsc;

    let (tx, rx) = mpsc::channel();
    let wallet_clone = wallet.clone();
    let keychain_mask_clone = keychain_mask.clone();

    // Spawn the retrieve operation in a separate thread.
    thread::spawn(move || {
        let is_stopped = Arc::new(AtomicBool::new(false));
        let api = Owner::new(wallet_clone, None, is_stopped.clone());

        let result = api.retrieve_txs(
            keychain_mask_clone.as_ref(),
            refresh_from_node,
            None,
            None,
            None,
            None,
            None,
        ).map(|res| serde_json::to_string(&res.txs).unwrap());

        // Send result back through channel (ignore if receiver dropped).
        let _ = tx.send(result);
    });

    // Wait for result with timeout.
    match rx.recv_timeout(Duration::from_secs(30)) {
        Ok(result) => result,
        Err(_) => Err(Error::GenericError("Operation timed out after 30 seconds".to_string()))
    }
}

/// Initialize a transaction as sender.
pub fn tx_create(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    amount: u64,
    minimum_confirmations: u64,
    selection_strategy_is_use_all: bool,
    epicbox_config: &str,
    address: &str,
    note: &str,
) -> Result<String, Error> {
    use std::sync::mpsc;

    let (tx, rx) = mpsc::channel();
    let wallet_clone = wallet.clone();
    let keychain_mask_clone = keychain_mask.clone();
    let epicbox_config = epicbox_config.to_string();
    let address = address.to_string();
    let note = note.to_string();

    // Spawn the create operation in a separate thread.
    thread::spawn(move || {
        let is_stopped = Arc::new(AtomicBool::new(false));
        let owner_api = Owner::new(wallet_clone, None, is_stopped.clone());
        let epicbox_conf = serde_json::from_str::<EpicboxConfig>(&epicbox_config).unwrap();

        owner_api.set_epicbox_config(Some(epicbox_conf));
        let init_send_args = InitTxSendArgs {
            method: "epicbox".to_string(),
            dest: address.to_string(),
            finalize: false,
            post_tx: false,
            fluff: false
        };

        let args = InitTxArgs {
            src_acct_name: Some("default".to_string()),
            amount,
            minimum_confirmations,
            max_outputs: 500,
            num_change_outputs: 1,
            selection_strategy_is_use_all,
            send_args: Some(init_send_args),
            message: Some(note.to_string()),
            ..Default::default()
        };

        let result = match owner_api.init_send_tx(keychain_mask_clone.as_ref(), args, is_stopped.clone()) {
            Ok(slate)=> {
                debug!("SLATE SEND RESPONSE IS  {:?}", slate);
                // Get transaction for the slate, we will use type to determing if we should finalize or receive tx.
                match owner_api.retrieve_txs(
                    keychain_mask_clone.as_ref(),
                    false,
                    None,
                    Some(slate.id),
                    None,
                    None,
                    None,
                ) {
                    Ok(txs_result) => {
                        let final_result = (
                            serde_json::to_string(&txs_result.txs).unwrap(),
                            serde_json::to_string(&slate).unwrap()
                        );
                        Ok(serde_json::to_string(&final_result).unwrap())
                    },
                    Err(e) => Err(e),
                }
            },
            Err(e)=> Err(e),
        };

        // Send result back through channel (ignore if receiver dropped).
        let _ = tx.send(result);
    });

    // Wait for result with timeout.
    match rx.recv_timeout(Duration::from_secs(30)) {
        Ok(result) => result,
        Err(_) => Err(Error::GenericError("Operation timed out after 30 seconds".to_string()))
    }
}

/// Cancel a transaction by ID.
pub fn tx_cancel(wallet: &Wallet, keychain_mask: Option<SecretKey>, tx_slate_id: Uuid) -> Result<String, Error> {
    use std::sync::mpsc;

    let (tx, rx) = mpsc::channel();
    let wallet_clone = wallet.clone();
    let keychain_mask_clone = keychain_mask.clone();

    // Spawn the cancel operation in a separate thread.
    thread::spawn(move || {
        let is_stopped = Arc::new(AtomicBool::new(false));
        let api = Owner::new(wallet_clone, None, is_stopped.clone());

        let result = match api.cancel_tx(keychain_mask_clone.as_ref(), None, Some(tx_slate_id)) {
            Ok(_) => Ok("cancelled".to_owned()),
            Err(e) => Err(e)
        };

        // Send result back through channel (ignore if receiver dropped).
        let _ = tx.send(result);
    });

    // Wait for result with timeout.
    match rx.recv_timeout(Duration::from_secs(10)) {
        Ok(result) => result,
        Err(_) => Err(Error::GenericError("Operation timed out after 10 seconds".to_string()))
    }
}

/// Get a transaction by slate ID.
pub fn tx_get(wallet: &Wallet, refresh_from_node: bool, tx_slate_id: &str) -> Result<String, Error> {
    use std::sync::mpsc;

    let uuid = Uuid::parse_str(tx_slate_id).map_err(|e| Error::GenericError(e.to_string()))?;
    let (tx, rx) = mpsc::channel();
    let wallet_clone = wallet.clone();

    // Spawn the get operation in a separate thread.
    thread::spawn(move || {
        let is_stopped = Arc::new(AtomicBool::new(false));
        let api = Owner::new(wallet_clone, None, is_stopped.clone());

        let result = api.retrieve_txs(None, refresh_from_node, None, Some(uuid), None, None, None)
            .map(|res| serde_json::to_string(&res.txs).unwrap());

        // Send result back through channel (ignore if receiver dropped).
        let _ = tx.send(result);
    });

    // Wait for result with timeout.
    match rx.recv_timeout(Duration::from_secs(10)) {
        Ok(result) => result,
        Err(_) => Err(Error::GenericError("Operation timed out after 10 seconds".to_string()))
    }
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
            return Err(Error::GenericError("Unable to get wallet config".to_string()))
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
        Err(Error::WalletSeedDoesntExist)
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
            return Err(Error::WalletSeedDoesntExist);
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
    use std::sync::mpsc;

    // get wallet object in order to use class methods
    let wallet = match get_wallet(&config) {
        Ok(wllet) => wllet,
        Err(e) => return Err(e),
    };

    //First close the wallet
    if let Ok(_) = close_wallet(&wallet) {
        let (tx, rx) = mpsc::channel();
        let wallet_clone = wallet.clone();

        // Spawn the delete operation in a separate thread.
        thread::spawn(move || {
            let is_stopped = Arc::new(AtomicBool::new(false));
            let api = Owner::new(wallet_clone, None, is_stopped.clone());

            let result = match api.delete_wallet(None) {
                Ok(_) => Ok("deleted".to_string()),
                Err(err) => Err(err),
            };

            // Send result back through channel (ignore if receiver dropped).
            let _ = tx.send(result);
        });

        // Wait for result with timeout.
        match rx.recv_timeout(Duration::from_secs(10)) {
            Ok(result) => result,
            Err(_) => Err(Error::GenericError("Operation timed out after 10 seconds".to_string()))
        }
    } else {
        Err(Error::GenericError("Error closing wallet".to_string()))
    }
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
    use std::sync::mpsc;

    let (tx, rx) = mpsc::channel();
    let wallet_clone = wallet.clone();
    let keychain_mask_clone = keychain_mask.clone();
    let message = message.to_string();
    let address = address.to_string();

    // Spawn the send operation in a separate thread.
    thread::spawn(move || {
        let is_stopped = Arc::new(AtomicBool::new(false));
        let api = Owner::new(wallet_clone, None, is_stopped.clone());
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

        let result = match api.init_send_tx(keychain_mask_clone.as_ref(), args, is_stopped.clone()) {
            Ok(slate) => {
                println!("{}", "CREATE_TX_SUCCESS");
                //Get transaction for slate, for UI display
                match api.retrieve_txs(
                    keychain_mask_clone.as_ref(),
                    false,
                    None,
                    Some(slate.id),
                    None,
                    None,
                    None,
                ) {
                    Ok(txs_result) => {
                        let tx_data = (
                            serde_json::to_string(&txs_result.txs).unwrap(),
                            serde_json::to_string(&slate).unwrap()
                        );
                        Ok(serde_json::to_string(&tx_data).unwrap())
                    },
                    Err(e) => Err(e),
                }
            } Err(err) => {
                println!("CREATE_TX_ERROR_IN_HTTP_SEND {}", err.to_string());
                Err(err)
            }
        };

        // Send result back through channel (ignore if receiver dropped).
        let _ = tx.send(result);
    });

    // Wait for result with timeout.
    match rx.recv_timeout(Duration::from_secs(60)) {
        Ok(result) => result,
        Err(_) => Err(Error::GenericError("Operation timed out after 60 seconds".to_string()))
    }
}

/// Create a wallet.
pub fn create_wallet(config: &str, phrase: &str, password: &str, name: &str) -> Result<String, Error> {
    let wallet_pass = ZeroingString::from(password);
    let wallet_config = match Config::from_str(&config) {
        Ok(config) => {
            config
        }, Err(e) => {
            return  Err(Error::GenericError(format!(
                "Error getting wallet config: {}",
                e.to_string()
            )));
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
            return Err(Error::GenericError(err.to_string()));
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
    use std::sync::mpsc;

    println!(">> get_wallet_info called with refresh_from_node={refresh_from_node}, min_confirmations={min_confirmations}");

    let (tx, rx) = mpsc::channel();
    let wallet_clone = wallet.clone();
    let keychain_mask_clone = keychain_mask.clone();

    // Spawn the retrieve operation in a separate thread.
    thread::spawn(move || {
        let is_stopped = Arc::new(AtomicBool::new(false));
        let api = Owner::new(wallet_clone, None, is_stopped.clone());

        let result = match api.retrieve_summary_info(keychain_mask_clone.as_ref(), refresh_from_node, min_confirmations) {
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
        };

        // Send result back through channel (ignore if receiver dropped).
        let _ = tx.send(result);
    });

    // Wait for result with timeout.
    match rx.recv_timeout(Duration::from_secs(30)) {
        Ok(result) => result,
        Err(_) => Err(Error::GenericError("Operation timed out after 30 seconds".to_string()))
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
            return Err(Error::GenericError("Unable to get wallet config".to_string()))
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
        return Err(Error::GenericError("Unable to scan, could not determine chain height".to_string()));
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
