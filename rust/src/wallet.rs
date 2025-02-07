use std::sync::Arc;
use serde_derive::{Deserialize, Serialize};
use stack_epic_keychain::ExtKeychain;
use stack_epic_util::{Mutex, ZeroingString};
use stack_epic_util::secp::SecretKey;
use stack_epic_wallet_api::Owner;
use stack_epic_wallet_config::EpicboxConfig;
use stack_epic_wallet_impls::{DefaultLCProvider, HTTPNodeClient};
use stack_epic_wallet_libwallet::{wallet_lock, AddressType, EpicboxAddress, Error, InitTxArgs, InitTxSendArgs, WalletInst};
use stack_epic_wallet_libwallet::api_impl::owner;
use uuid::Uuid;
use crate::config::Config;
use crate::get_wallet;

use crate::EpicWalletControllerError;
use stack_epic_wallet_libwallet::Address;

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

#[derive(Serialize, Deserialize)]
struct Strategy {
    selection_strategy_is_use_all: bool,
    total: u64,
    fee: u64,
}


/*
    Get transaction fees
    all possible Coin/Output selection strategies.
*/
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

/*
    Init tx as sender
*/
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
    let owner_api = Owner::new(wallet.clone(), None);
    let epicbox_conf = serde_json::from_str::<EpicboxConfig>(epicbox_config).unwrap();

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


    match owner_api.init_send_tx(keychain_mask.as_ref(), args) {
        Ok(slate)=> {
            debug!("SLATE SEND RESPONSE IS  {:?}", slate);
            //Get transaction for the slate, we will use type to determing if we should finalize or receive tx
            let txs = match owner_api.retrieve_txs(
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
            let final_result = (
                serde_json::to_string(&txs.1).unwrap(),
                serde_json::to_string(&slate).unwrap()
            );
            let str_result = serde_json::to_string(&final_result).unwrap();
            Ok(str_result)
        },
        Err(e)=> {
            return Err(e);
        }
    }
}

/*
    Cancel tx by id
*/
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

/*
    Get transaction by slate id
*/
pub fn tx_get(wallet: &Wallet, refresh_from_node: bool, tx_slate_id: &str) -> Result<String, Error> {
    let api = Owner::new(wallet.clone(), None);
    let uuid = Uuid::parse_str(tx_slate_id).map_err(|e| EpicWalletControllerError::GenericError(e.to_string())).unwrap();
    let txs = api.retrieve_txs(None, refresh_from_node, None, Some(uuid)).unwrap();
    Ok(serde_json::to_string(&txs.1).unwrap())
}

pub fn convert_deci_to_nano(amount: f64) -> u64 {
    let base_nano = 100000000;
    let nano = amount * base_nano as f64;
    nano as u64
}

pub fn nano_to_deci(amount: u64) -> f64 {
    let base_nano = 100000000;
    let decimal = amount as f64 / base_nano as f64;
    decimal
}

/*

*/
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
