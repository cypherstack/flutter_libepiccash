use std::ffi::{c_void, CStr, CString};
use std::os::raw::c_char;

use uuid::Uuid;

use stack_epic_wallet_api::{self, Owner};
use stack_epic_wallet_config::EpicboxConfig;
use stack_epic_wallet_libwallet::Error;
use stack_epic_wallet_controller::Error as EpicWalletControllerError;

use stack_epic_util::secp::key::SecretKey;

use crate::config::Config;

use crate::mnemonic::mnemonic;
use crate::mnemonic::create_seed;
use crate::mnemonic::_get_mnemonic;

use crate::wallet::Wallet;
use crate::wallet::create_wallet;
use crate::wallet::recover_from_mnemonic;
use crate::wallet::open_wallet;
use crate::wallet::get_wallet_info;
use crate::wallet::validate_address;
use crate::wallet::wallet_scan_outputs;
use crate::wallet::tx_strategies;
use crate::wallet::tx_create;
use crate::wallet::txs_get;
use crate::wallet::tx_cancel;
use crate::wallet::delete_wallet;
use crate::wallet::tx_send_http;
use crate::wallet::get_chain_height;

use crate::listener::Listener;
use crate::listener::listener_spawn;
use crate::listener::listener_cancel;
use crate::listener::listener_cancelled;
use crate::init_logger;

use ffi_helpers::task::TaskHandle;

/// Initialize a new wallet via FFI.
#[no_mangle]
pub unsafe extern "C" fn wallet_init(
    config: *const c_char,
    mnemonic: *const c_char,
    password: *const c_char,
    name: *const c_char
) -> *const c_char {

    let result = match _wallet_init(config, mnemonic, password, name) {
        Ok(created) => {
            created
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// Get a new mnemonic.
#[no_mangle]
pub unsafe extern "C" fn get_mnemonic() -> *const c_char {
    let result = match _get_mnemonic() {
        Ok(phrase) => {
            phrase
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to initialize a new wallet.
fn _wallet_init(
    config: *const c_char,
    mnemonic: *const c_char,
    password: *const c_char,
    name: *const c_char
) -> Result<*const c_char, Error> {

    let config = unsafe { CStr::from_ptr(config) };
    let mnemonic = unsafe { CStr::from_ptr(mnemonic) };
    let password = unsafe { CStr::from_ptr(password) };
    let name = unsafe { CStr::from_ptr(name) };

    let str_password = match password.to_str() {
        Ok(str_pass) => {str_pass}, Err(e) => {return Err(
            Error::from(EpicWalletControllerError::GenericError(format!("{}", e.to_string())))
        )}
    };

    let str_config = match config.to_str() {
        Ok(str_conf) => {str_conf}, Err(e) => {return Err(
            Error::from(EpicWalletControllerError::GenericError(format!("{}", e.to_string())))
        )}
    };

    let phrase = match mnemonic.to_str() {
        Ok(str_phrase) => {str_phrase}, Err(e) => {return Err(
            Error::from(EpicWalletControllerError::GenericError(format!("{}", e.to_string())))
        )}
    };

    let str_name = match name.to_str() {
        Ok(str_name) => {str_name}, Err(e) => {return Err(
            Error::from(EpicWalletControllerError::GenericError(format!("{}", e.to_string())))
        )}
    };

    let mut create_msg = "".to_string();
    match create_wallet(str_config, phrase, str_password, str_name) {
        Ok(_) => {
            create_msg.push_str("");
        },Err(e) => {
            return Err(e);
        }
    }
    let s = CString::new(create_msg).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Open a wallet via FFI.
#[no_mangle]
pub unsafe extern "C"  fn rust_open_wallet(
    config: *const c_char,
    password: *const c_char,
) -> *const c_char {
    init_logger();
    let result = match _open_wallet(
        config,
        password
    ) {
        Ok(wallet) => {
            wallet
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to open a wallet.
fn _open_wallet(
    config: *const c_char,
    password: *const c_char,
) -> Result<*const c_char, Error> {
    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };

    let str_config = c_conf.to_str().unwrap();
    let str_password = c_password.to_str().unwrap();

    let mut result = String::from("");
    match open_wallet(&str_config, str_password) {
        Ok(res) => {
            let wlt = res.0;
            let sek_key = res.1;
            let wallet_int = Box::into_raw(Box::new(wlt)) as i64;
            let wallet_data = (wallet_int, sek_key);
            let wallet_ptr = serde_json::to_string(&wallet_data).unwrap();
            result.push_str(&wallet_ptr);
        }
        Err(err) => {
            return Err(err);
        }
    };

    let s = CString::new(result).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Get wallet balances via FFI.
#[no_mangle]
pub unsafe extern "C"  fn rust_wallet_balances(
    wallet: *const c_char,
    refresh: *const c_char,
    min_confirmations: *const c_char,
) -> *const c_char {
    let wallet_ptr = CStr::from_ptr(wallet);
    let c_refresh = CStr::from_ptr(refresh);
    let minimum_confirmations = CStr::from_ptr(min_confirmations);
    let minimum_confirmations: u64 = minimum_confirmations.to_str().unwrap().to_string().parse().unwrap();

    let refresh_from_node: u64 = c_refresh.to_str().unwrap().to_string().parse().unwrap();
    let refresh = match refresh_from_node {
        0 => false,
        _=> true
    };

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _wallet_balances(
        wallet,
        sek_key,
        refresh,
        minimum_confirmations
    ) {
        Ok(balances) => {
            balances
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to get wallet balances.
fn _wallet_balances(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    refresh: bool,
    min_confirmations: u64,
) -> Result<*const c_char, Error> {
    // Print arguments for debugging/test-vector use.
    println!(
        ">> _wallet_balances called with refresh={refresh}, min_confirmations={min_confirmations}"
    );

    let mut wallet_info_str = String::new();

    // Call get_wallet_info under the hood.
    match get_wallet_info(wallet, keychain_mask, refresh, min_confirmations) {
        Ok(info) => {
            // Print intermediate data
            println!(">> _wallet_balances got info: {:?}", info);

            // Convert to JSON.
            let str_wallet_info = serde_json::to_string(&info).unwrap();
            wallet_info_str.push_str(&str_wallet_info);
        }
        Err(e) => {
            println!(">> _wallet_balances encountered error: {e}");
            return Err(e);
        }
    }

    // Convert final string result into a *const c_char.
    let s = CString::new(wallet_info_str).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Hand off responsibility to caller.
    Ok(p)
}

/// Recover a wallet from a mnemonic via FFI.
#[no_mangle]
pub unsafe extern "C"  fn rust_recover_from_mnemonic(
    config: *const c_char,
    password: *const c_char,
    mnemonic: *const c_char,
    name: *const c_char
) -> *const c_char {

    let result = match _recover_from_mnemonic(
        config,
        password,
        mnemonic,
        name
    ) {
        Ok(recovered) => {
            recovered
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to recover a wallet from a mnemonic.
fn _recover_from_mnemonic(
    config: *const c_char,
    password: *const c_char,
    mnemonic: *const c_char,
    name: *const c_char
) -> Result<*const c_char, Error> {
    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };
    let c_mnemonic = unsafe { CStr::from_ptr(mnemonic) };
    let c_name = unsafe { CStr::from_ptr(name) };

    let input_conf = c_conf.to_str().unwrap();
    let str_password = c_password.to_str().unwrap();
    let wallet_config = match Config::from_str(&input_conf.to_string()) {
        Ok(config) => {
            config
        }, Err(err) => {
            return Err(Error::from(EpicWalletControllerError::GenericError(format!(
                "Wallet config error : {}",
                err.to_string()
            ))))
        }
    };
    let phrase = c_mnemonic.to_str().unwrap();
    let name = c_name.to_str().unwrap();

    let mut recover_response = "".to_string();
    match recover_from_mnemonic(phrase, str_password, &wallet_config, name) {
        Ok(_)=> {
            recover_response.push_str("recovered");
        },
        Err(e)=> {
            return Err(e);
        }
    }
    let s = CString::new(recover_response).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Validate an address via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_wallet_scan_outputs(
    wallet: *const c_char,
    start_height: *const c_char,
    number_of_blocks: *const c_char,
) -> *const c_char {
    let wallet_ptr = CStr::from_ptr(wallet);
    let c_start_height = CStr::from_ptr(start_height);
    let c_number_of_blocks = CStr::from_ptr(number_of_blocks);
    let start_height: u64 = c_start_height.to_str().unwrap().to_string().parse().unwrap();
    let number_of_blocks: u64 = c_number_of_blocks.to_str().unwrap().to_string().parse().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _wallet_scan_outputs(
        wallet,
        sek_key,
        start_height,
        number_of_blocks
    ) {
        Ok(scan) => {
            scan
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to scan outputs.
fn _wallet_scan_outputs(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    start_height: u64,
    number_of_blocks: u64
) -> Result<*const c_char, Error> {
    // Print arguments for debugging/test-vector use.
    println!(
        ">> _wallet_scan_outputs called with start_height={start_height}, number_of_blocks={number_of_blocks}"
    );

    let mut scan_result = String::new();

    // Call wallet_scan_outputs under the hood.
    match wallet_scan_outputs(
        wallet,
        keychain_mask,
        Some(start_height),
        Some(number_of_blocks)
    ) {
        Ok(scan_str) => {
            // Print intermediate data.
            println!(">> _wallet_scan_outputs result: {scan_str}");
            scan_result.push_str(&scan_str);
        },
        Err(err) => {
            println!(">> _wallet_scan_outputs encountered error: {err}");
            return Err(err);
        },
    }

    // Convert final string result into a *const c_char.
    let s = CString::new(scan_result).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Hand off responsibility to caller.
    Ok(p)
}

/// Create a transaction via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_create_tx(
    wallet: *const c_char,
    amount: *const c_char,
    to_address: *const c_char,
    secret_key_index: *const c_char,
    epicbox_config: *const c_char,
    confirmations: *const c_char,
    note: *const c_char,
    return_slate_flag: *const c_char,
) -> *const c_char {
    let wallet_data = CStr::from_ptr(wallet).to_str().unwrap();
    let min_confirmations: u64 = CStr::from_ptr(confirmations).to_str().unwrap().to_string().parse().unwrap();
    let amount: u64 = CStr::from_ptr(amount).to_str().unwrap().to_string().parse().unwrap();
    let address = CStr::from_ptr(to_address).to_str().unwrap();
    let note = CStr::from_ptr(note).to_str().unwrap();
    let key_index: u32 = CStr::from_ptr(secret_key_index).to_str().unwrap().parse().unwrap();
    let epicbox_config = CStr::from_ptr(epicbox_config).to_str().unwrap();

    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();

    let c_return_slate  = CStr::from_ptr(return_slate_flag);
    let return_slate_u64: u64 = c_return_slate.to_str().unwrap().parse().unwrap_or(0);
    let return_slate    = return_slate_u64 != 0;

    let listen = Listener {
        wallet_ptr_str: wallet_data.to_string(),
        epicbox_config: epicbox_config.parse().unwrap()
    };

    let handle = listener_spawn(&listen);
    listener_cancel(handle);
    debug!("LISTENER CANCELLED IS {}", listener_cancelled(handle));

    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _create_tx(
        wallet,
        sek_key,
        amount,
        address,
        key_index,
        epicbox_config,
        min_confirmations,
        note,
        return_slate
    ) {
        Ok(slate) => {
            // Spawn listener again.
            listener_spawn(&listen);
            slate
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result

}

/// A helper to create a transaction.
fn _create_tx(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    amount: u64,
    address: &str,
    _secret_key_index: u32,
    epicbox_config: &str,
    minimum_confirmations: u64,
    note: &str,
    return_slate: bool,
) -> Result<*const c_char, Error> {
    let  mut message = String::from("");
    match tx_create(
        &wallet,
        keychain_mask.clone(),
        amount,
        minimum_confirmations,
        false,
        epicbox_config,
        address,
        note,
        Some(return_slate),
    ) {
        Ok(slate) => {
            let empty_json = format!(r#"{{"slate_msg": ""}}"#);
            let create_response = (&slate, &empty_json);
            let str_create_response = serde_json::to_string(&create_response).unwrap();
            message.push_str(&str_create_response);
        },
        Err(e) => {
            message.push_str(&e.to_string());
            return Err(e);
        }
    }

    let s = CString::new(message).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Get transactions via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_txs_get(
    wallet: *const c_char,
    refresh_from_node: *const c_char,
) -> *const c_char {
    let c_wallet = CStr::from_ptr(wallet);
    let c_refresh_from_node = CStr::from_ptr(refresh_from_node);
    let refresh_from_node: u64 = c_refresh_from_node.to_str().unwrap().to_string().parse().unwrap();
    let refresh = match refresh_from_node {
        0 => false,
        _=> true
    };

    let wallet_data = c_wallet.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _txs_get(
        wallet,
        sek_key,
        refresh,
    ) {
        Ok(txs) => {
            txs
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to get transactions.
fn _txs_get(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    refresh_from_node: bool,
) -> Result<*const c_char, Error> {
    let mut txs_result = "".to_string();
    match txs_get(
        wallet,
        keychain_mask,
        refresh_from_node
    ) {
        Ok(txs) => {
            txs_result.push_str(&txs);
        },
        Err(err) => {
            return Err(err);
        },
    }

    let s = CString::new(txs_result).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Cancel a transaction via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_tx_cancel(
    wallet: *const c_char,
    tx_id: *const c_char,
) -> *const c_char {
    let wallet_ptr = CStr::from_ptr(wallet);
    let tx_id = CStr::from_ptr(tx_id);
    let tx_id = tx_id.to_str().unwrap();
    let uuid = Uuid::parse_str(tx_id).map_err(|e| EpicWalletControllerError::GenericError(e.to_string())).unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _tx_cancel(
        wallet,
        sek_key,
        uuid,
    ) {
        Ok(cancelled) => {
            cancelled
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to cancel a transaction.
fn _tx_cancel(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    tx_id: Uuid,
) -> Result<*const c_char, Error>{
    let mut cancel_msg = "".to_string();
    match  tx_cancel(wallet, keychain_mask, tx_id) {
        Ok(_) => {
            cancel_msg.push_str("");
        },Err(err) => {
            return Err(err);
        }
    }
    let s = CString::new(cancel_msg).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Get chain height via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_get_chain_height(
    config: *const c_char,
) -> *const c_char {
    let result = match _get_chain_height(
        config
    ) {
        Ok(chain_height) => {
            chain_height
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to get chain height.
fn _get_chain_height(config: *const c_char) -> Result<*const c_char, Error> {
    let c_config = unsafe { CStr::from_ptr(config) };
    let str_config = c_config.to_str().unwrap();
    let mut chain_height = "".to_string();
    match get_chain_height(&str_config) {
        Ok(chain_tip) => {
            chain_height.push_str(&chain_tip.to_string());
        },
        Err(e) => {
            debug!("CHAIN_HEIGHT_ERROR {}", e.to_string());
            return Err(e);
        },
    }
    let s = CString::new(chain_height).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Delete a wallet via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_delete_wallet(
    _wallet: *const c_char,
    config: *const c_char,
) -> *const c_char  {
    let c_conf = CStr::from_ptr(config);
    let _config = Config::from_str(c_conf.to_str().unwrap()).unwrap(); // TODO: handle error here.

    let result = match _delete_wallet(
        _config,
    ) {
        Ok(deleted) => {
            deleted
        }, Err(err) => {
            let error_msg = format!("Error deleting wallet from _delete_wallet in rust_delete_wallet {}", &err.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to delete a wallet.
fn _delete_wallet(
    config: Config,
) -> Result<*const c_char, Error> {
    let mut delete_result = String::from("");
    match delete_wallet(config) {
        Ok(deleted) => {
            delete_result.push_str(&deleted);
        },
        Err(err) => {
            return Err(err);
        },
    }
    let s = CString::new(delete_result).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)

}

/// Send a transaction via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_tx_send_http(
    wallet: *const c_char,
    selection_strategy_is_use_all: *const c_char,
    minimum_confirmations: *const c_char,
    message: *const c_char,
    amount: *const c_char,
    address: *const c_char,
) -> *const c_char  {
    let c_wallet = CStr::from_ptr(wallet);
    let c_strategy_is_use_all = CStr::from_ptr(selection_strategy_is_use_all);
    let strategy_is_use_all: u64 = c_strategy_is_use_all.to_str().unwrap().to_string().parse().unwrap();
    let strategy_use_all = match strategy_is_use_all {
        0 => false,
        _=> true
    };
    let c_minimum_confirmations = CStr::from_ptr(minimum_confirmations);
    let minimum_confirmations: u64 = c_minimum_confirmations.to_str().unwrap().to_string().parse().unwrap();
    let c_message = CStr::from_ptr(message);
    let str_message = c_message.to_str().unwrap();
    let c_amount = CStr::from_ptr(amount);
    let amount: u64 = c_amount.to_str().unwrap().to_string().parse().unwrap();
    let c_address = CStr::from_ptr(address);
    let str_address = c_address.to_str().unwrap();

    let wallet_data = c_wallet.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;
    ensure_wallet!(wlt, wallet);

    let result = match _tx_send_http(
        wallet,
        sek_key,
        strategy_use_all,
        minimum_confirmations,
        str_message,
        amount,
        str_address
    ) {
        Ok(tx_data) => {
            tx_data
        }, Err(err ) => {
            let error_msg = format!("Error {}", &err.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to send a transaction.
fn _tx_send_http(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    selection_strategy_is_use_all: bool,
    minimum_confirmations: u64,
    message: &str,
    amount: u64,
    address: &str
) -> Result<*const c_char, Error> {
    let mut send_result = String::from("");
    match tx_send_http(
        wallet,
        keychain_mask,
        selection_strategy_is_use_all,
        minimum_confirmations,
        message,
        amount,
        address
    ) {
        Ok(sent) => {
            let empty_json = format!(r#"{{"slate_msg": ""}}"#);
            let create_response = (&sent, &empty_json);
            let str_create_response = serde_json::to_string(&create_response).unwrap();
            send_result.push_str(&str_create_response);
        },
        Err(err) => {
            return Err(err);
        },
    }
    let s = CString::new(send_result).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Get a wallet address via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_get_wallet_address(
    wallet: *const c_char,
    index: *const c_char,
    epicbox_config: *const c_char,
) -> *const c_char {
    let wallet_ptr = CStr::from_ptr(wallet);
    let index = CStr::from_ptr(index);
    let epicbox_config = CStr::from_ptr(epicbox_config);
    let epicbox_config = epicbox_config.to_str().unwrap();
    let index: u32 = index.to_str().unwrap().to_string().parse().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);
    let result = match _get_wallet_address(
        wallet,
        sek_key,
        index,
        epicbox_config
    ) {
        Ok(address) => {
            address
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to get a wallet address.
fn _get_wallet_address(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    index: u32,
    epicbox_config: &str
) -> Result<*const c_char, Error> {
    let address = get_wallet_address(&wallet, keychain_mask, index, epicbox_config);
    let s = CString::new(address).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

/// Get a wallet address.
pub fn get_wallet_address(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    index: u32,
    epicbox_config: &str,
) -> String {

    let epicbox_conf = serde_json::from_str::<EpicboxConfig>(epicbox_config).unwrap();
    let api = Owner::new(wallet.clone(), None);
    let address = api.get_public_address(keychain_mask.as_ref(), index).unwrap();
    format!("{}@{}", address.public_key, epicbox_conf.epicbox_domain.as_deref().unwrap_or(""))
}

/// Validate an address via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_validate_address(
    address: *const c_char,
) -> *const c_char {
    let address = unsafe { CStr::from_ptr(address) };
    let str_address = address.to_str().unwrap();
    let validate = validate_address(str_address);
    let return_value = match validate {
        true => 1,
        false => 0
    };

    let s = CString::new(return_value.to_string()).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    p
}

/// Validate an address.
#[no_mangle]
pub unsafe extern "C" fn rust_get_tx_fees(
    wallet: *const c_char,
    c_amount: *const c_char,
    min_confirmations: *const c_char,
) -> *const c_char {

    let minimum_confirmations = CStr::from_ptr(min_confirmations);
    let minimum_confirmations: u64 = minimum_confirmations.to_str().unwrap().to_string().parse().unwrap();
    let wallet_ptr = CStr::from_ptr(wallet);

    let amount = CStr::from_ptr(c_amount);
    let amount: u64 = amount.to_str().unwrap().to_string().parse().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _get_tx_fees(
        &wallet,
        sek_key,
        amount,
        minimum_confirmations,
    ) {
        Ok(fees) => {
            fees
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr();
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

/// A helper to get transaction fees.
fn _get_tx_fees(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    amount: u64,
    minimum_confirmations: u64,
) -> Result<*const c_char, Error> {
    let mut fees_data = "".to_string();
    match tx_strategies(wallet, keychain_mask, amount, minimum_confirmations) {
        Ok(fees) => {
            fees_data.push_str(&fees);
        }, Err(e) => {
            return Err(e);
        }
    }
    let s = CString::new(fees_data).unwrap();
    let p = s.as_ptr();
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s.
    Ok(p)
}

/// Start a listener via FFI.
#[no_mangle]
pub unsafe extern "C" fn rust_epicbox_listener_start(
    wallet: *const c_char,
    epicbox_config: *const c_char,
) -> *mut c_void {
    let wallet_ptr = CStr::from_ptr(wallet);
    let epicbox_config = CStr::from_ptr(epicbox_config);
    let epicbox_config = epicbox_config.to_str().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    // let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let listen = Listener {
        wallet_ptr_str: wallet_data.to_string(),
        epicbox_config: epicbox_config.parse().unwrap()
    };

    let handler = listener_spawn(&listen);
    let handler_value = handler.read();
    let boxed_handler = Box::new(handler_value);
    Box::into_raw(boxed_handler) as *mut _
}

/// Cancel a listener via FFI.
#[no_mangle]
pub unsafe extern "C" fn _listener_cancel(handler: *mut c_void) -> *const c_char {
    let handle = handler as *mut TaskHandle<usize>;
    listener_cancel(handle);
    let error_msg = format!("{}", listener_cancelled(handle));
    let error_msg_ptr = CString::new(error_msg).unwrap();
    let ptr = error_msg_ptr.as_ptr();
    std::mem::forget(error_msg_ptr);
    ptr
}

#[cfg(test)]
mod mnemonic_tests {
    use super::*;
    use std::collections::HashSet;

    // Test the create_seed function.
    #[test]
    fn test_create_seed() {
        // Test with different seed lengths.
        let lengths = [16, 24, 32];

        for &length in lengths.iter() {
            let seed = create_seed(length);

            // Verify seed length.
            assert_eq!(seed.len(), length as usize, "Seed length should match requested length");

            // Verify seed contains random values (not all zeros).
            let unique_bytes: HashSet<_> = seed.iter().collect();
            assert!(unique_bytes.len() > 1, "Seed should contain random values");

            println!("Successfully generated seed of length {}: {:?}", length, seed);
        }
    }

    // Test the mnemonic() function.
    #[test]
    fn test_mnemonic_generation() {
        match mnemonic() {
            Ok(phrase) => {
                // Verify the mnemonic is not empty.
                assert!(!phrase.is_empty(), "Mnemonic phrase should not be empty");

                // Split into words and verify word count (should be 24 words for 32 bytes entropy).
                let words: Vec<&str> = phrase.split_whitespace().collect();
                assert_eq!(words.len(), 24, "Mnemonic should contain 24 words");

                // Verify all words are lowercase and contain only letters.
                for word in &words {
                    assert!(word.chars().all(|c| c.is_ascii_lowercase()),
                            "Words should only contain lowercase letters");
                }

                println!("Successfully generated mnemonic phrase: {}", phrase);
            },
            Err(e) => {
                panic!("Failed to generate mnemonic: {:?}", e);
            }
        }
    }

    // Test the _get_mnemonic FFI function.
    #[test]
    fn test_get_mnemonic_ffi() {
        unsafe {
            match _get_mnemonic() {
                Ok(c_str_ptr) => {
                    // Convert C string pointer back to Rust string.
                    let c_str = CStr::from_ptr(c_str_ptr);
                    let phrase = c_str.to_str().expect("Invalid UTF-8 in mnemonic");

                    // Verify the mnemonic is valid.
                    assert!(!phrase.is_empty(), "Mnemonic phrase should not be empty");

                    let words: Vec<&str> = phrase.split_whitespace().collect();
                    assert_eq!(words.len(), 24, "Mnemonic should contain 24 words");

                    println!("Successfully generated FFI mnemonic: {}", phrase);

                    // Clean up the C string (since we're in a test).
                    let _ = CString::from_raw(c_str_ptr as *mut i8);
                },
                Err(e) => {
                    panic!("Failed to generate FFI mnemonic: {:?}", e);
                }
            }
        }
    }

    // Test multiple mnemonic generations to ensure uniqueness.
    #[test]
    fn test_mnemonic_uniqueness() {
        let mut phrases = HashSet::new();

        // Generate multiple phrases and check that they're unique.
        for i in 0..5 {
            match mnemonic() {
                Ok(phrase) => {
                    assert!(!phrases.contains(&phrase),
                            "Generated duplicate mnemonic on iteration {}", i);
                    phrases.insert(phrase.clone());
                    println!("Generated unique mnemonic {}: {}", i + 1, phrase);
                },
                Err(e) => {
                    panic!("Failed to generate mnemonic on iteration {}: {:?}", i, e);
                }
            }
        }
    }

    // Test that generated mnemonics can be parsed back into valid seeds.
    #[test]
    fn test_mnemonic_reversibility() {
        use stack_epic_keychain::mnemonic::to_entropy;

        match mnemonic() {
            Ok(phrase) => {
                // Try to convert mnemonic back to entropy.
                match to_entropy(&phrase) {
                    Ok(entropy) => {
                        assert_eq!(entropy.len(), 32,
                                   "Entropy from mnemonic should be 32 bytes");
                        println!("Successfully verified mnemonic reversibility for: {}", phrase);
                    },
                    Err(e) => {
                        panic!("Failed to convert mnemonic back to entropy: {:?}", e);
                    }
                }
            },
            Err(e) => {
                panic!("Failed to generate mnemonic: {:?}", e);
            }
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn rust_tx_receive(
    wallet: *const c_char,
    slate_json: *const c_char,
) -> *const c_char {
    let wallet_str  = CStr::from_ptr(wallet).to_str().unwrap();
    let slate_str   = CStr::from_ptr(slate_json).to_str().unwrap();

    let (wlt, sek_key): (i64, Option<SecretKey>) =
        serde_json::from_str(wallet_str).unwrap();

    ensure_wallet!(wlt, wallet);

    match _tx_receive(wallet, sek_key, slate_str) {
        Ok(ptr)  => ptr,
        Err(e)   => {
            let err = CString::new(format!("Error {}", e)).unwrap();
            let p   = err.as_ptr();
            std::mem::forget(err);
            p
        }
    }
}

fn _tx_receive(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    slate_json: &str,
) -> Result<*const c_char, Error> {
    let mut out = String::new();

    match tx_receive(wallet, keychain_mask, slate_json) {
        Ok(processed_slate) => {
            // Keep the outer API uniform with (<slate>, {"slate_msg":""}).
            let empty_json      = r#"{"slate_msg": ""}"#;
            let response_tuple  = (&processed_slate, &empty_json);
            out.push_str(&serde_json::to_string(&response_tuple).unwrap());
        }
        Err(e) => {
            return Err(e);
        }
    }

    let c_out = CString::new(out).unwrap();
    let p     = c_out.as_ptr();
    std::mem::forget(c_out);
    Ok(p)
}

#[no_mangle]
pub unsafe extern "C" fn rust_tx_finalize(
    wallet: *const c_char,
    slate_json: *const c_char,
) -> *const c_char {
    let wallet_str  = CStr::from_ptr(wallet).to_str().unwrap();
    let slate_str   = CStr::from_ptr(slate_json).to_str().unwrap();

    let (wlt, sek_key): (i64, Option<SecretKey>) =
        serde_json::from_str(wallet_str).unwrap();

    ensure_wallet!(wlt, wallet);

    match _tx_finalize(wallet, sek_key, slate_str) {
        Ok(ptr)  => ptr,
        Err(e)   => {
            let err = CString::new(format!("Error {}", e)).unwrap();
            let p   = err.as_ptr();
            std::mem::forget(err);
            p
        }
    }
}

fn _tx_finalize(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    slate_json: &str,
) -> Result<*const c_char, Error> {
    let mut out = String::new();

    match tx_finalize(wallet, keychain_mask, slate_json) {
        Ok(finalised_slate) => {
            // Same tuple shape as elsewhere
            let empty_json      = r#"{"slate_msg": ""}"#;
            let response_tuple  = (&finalised_slate, &empty_json);
            out.push_str(&serde_json::to_string(&response_tuple).unwrap());
        }
        Err(e) => {
            return Err(e);
        }
    }

    let c_out = CString::new(out).unwrap();
    let p     = c_out.as_ptr();
    std::mem::forget(c_out);
    Ok(p)
}
