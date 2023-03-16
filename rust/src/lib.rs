use std::cmp::Ordering;
use std::os::raw::{c_char};
use std::ffi::{CString, CStr, c_int};
use std::sync::Arc;
use std::path::{Path};
use rand::thread_rng;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use stack_epic_wallet_api::{self, Owner};
use stack_epic_wallet_config::{WalletConfig, EpicboxConfig};
use stack_epic_wallet_libwallet::api_impl::types::{InitTxArgs, InitTxSendArgs};
use stack_epic_wallet_libwallet::api_impl::owner;
use stack_epic_wallet_impls::{DefaultLCProvider, DefaultWalletImpl, EpicboxListenChannel, HTTPNodeClient};

use stack_epic_keychain::mnemonic;
use stack_epic_wallet_util::stack_epic_core::global::ChainTypes;
use stack_epic_util::file::get_first_line;
use stack_epic_wallet_util::stack_epic_util::ZeroingString;
use stack_epic_util::Mutex;
use stack_epic_wallet_libwallet::{scan, wallet_lock, NodeClient, WalletInst, WalletLCProvider, Error, ErrorKind};

use stack_epic_wallet_util::stack_epic_keychain::{Keychain, ExtKeychain};

use stack_epic_util::secp::rand::Rng;
use stack_epic_util::secp::key::{SecretKey};

use stack_test_epicboxlib::types::{EpicboxAddress};
use android_logger::FilterBuilder;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Config {
    pub wallet_dir: String,
    pub check_node_api_http_addr: String,
    pub chain: String,
    pub account: Option<String>,
    pub api_listen_port: u16,
    pub api_listen_interface: String
}

type Wallet = Arc<
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

macro_rules! ensure_wallet (
    ($wallet_ptr:expr, $wallet:ident) => (
        if ($wallet_ptr as *mut Wallet).as_mut().is_none() {
            println!("{}", "WALLET_IS_NOT_OPEN");
        }
        let $wallet = ($wallet_ptr as *mut Wallet).as_mut().unwrap();
    )
);

macro_rules! error {
    ($result:expr) => {
        error!($result, 0);
    };
    ($result:expr, $error:expr) => {
        match $result {
            Ok(value) => value,
            Err(_e) => {
                // ffi_helpers::update_last_error(e);
                return $error;
            }
        }
    };
}

macro_rules! cstr {
    ($ptr:expr) => {
        cstr!($ptr, 0);
    };
    ($ptr:expr, $error:expr) => {
        error!(CStr::from_ptr($ptr).to_str(), $error)
    };
}


fn init_logger() {
    android_logger::init_once(
        AndroidConfig::default()
            .with_min_level(Level::Trace)
            .with_tag("libepiccash")
            .with_filter(FilterBuilder::new().parse("debug,epic-cash-wallet::crate=super").build()),
    );
}

impl Config {
    fn from_str(json: &str) -> Result<Self, Error> {
        serde_json::from_str::<Config>(json).map_err(|err| Error::from(ErrorKind::GenericError(err.to_string())))
    }
}

/*
    Create Wallet config
*/
fn create_wallet_config(config: Config) -> Result<WalletConfig, Error> {
    let chain_type = match config.chain.as_ref() {
        "mainnet" => ChainTypes::Mainnet,
        "floonet" => ChainTypes::Floonet,
        "usertesting" => ChainTypes::UserTesting,
        "automatedtesting" => ChainTypes::AutomatedTesting,
        _ => ChainTypes::Floonet,
    };

    let api_secret_path = config.wallet_dir.clone() + "/.api_secret";
    let api_listen_port = config.api_listen_port;

    Ok(WalletConfig {
        chain_type: Some(chain_type),
        api_listen_interface: config.api_listen_interface,
        api_listen_port,
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
        owner_api_listen_port: Some(WalletConfig::default_owner_api_listen_port()),
    })
}

#[macro_use] extern crate log;
extern crate android_logger;
extern crate simplelog;

use log::Level;
use android_logger::Config as AndroidConfig;
use ffi_helpers::{export_task, Task};
use ffi_helpers::task::{CancellationToken};
// use stack_epic_wallet_libwallet::api_impl::owner::get_public_address;

#[no_mangle]
pub unsafe extern "C" fn get_mnemonic() -> *const c_char {
    let result = mnemonic();
    let cstr = error!(result, std::ptr::null());
    let cstr = error!(CString::new(cstr), std::ptr::null());
    cstr.into_raw()
}

/*
    Create a new wallet
*/

#[no_mangle]
pub unsafe extern "C" fn wallet_init(
    config: *const c_char,
    mnemonic: *const c_char,
    password: *const c_char,
    name: *const c_char
) -> *const c_char {

    let config = cstr!(config, std::ptr::null());
    let mnemonic = cstr!(mnemonic, std::ptr::null());
    let password = cstr!(password, std::ptr::null());
    let name = cstr!(name, std::ptr::null());
    let result = create_wallet(config, mnemonic, password, name);
    let cstr = error!(result, std::ptr::null());
    let cstr = error!(CString::new(cstr), std::ptr::null());
    cstr.into_raw()
}

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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

fn _open_wallet(
    config: *const c_char,
    password: *const c_char,
) -> Result<*const c_char, Error> {
    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };

    let str_config = c_conf.to_str().unwrap();
    let str_password = c_password.to_str().unwrap();

    let mut result = String::from("");
    match open_wallet(&str_config.clone(), str_password) {
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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}


/*
    Get wallet info
    This contains wallet balances
*/
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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

fn _wallet_balances(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    refresh: bool,
    min_confirmations: u64,
) -> Result<*const c_char, Error> {
    let mut wallet_info = "".to_string();
    match get_wallet_info(
        &wallet,
        keychain_mask,
        refresh,
        min_confirmations
    ) {
        Ok(info) => {
            let str_wallet_info = serde_json::to_string(&info).unwrap();
            wallet_info.push_str(&str_wallet_info);
        },Err(e) => {
            return Err(e);
        }
    }
    let s = CString::new(wallet_info).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}



#[no_mangle]
pub unsafe extern "C"  fn rust_recover_from_mnemonic(
    config: *const c_char,
    password: *const c_char,
    mnemonic: *const c_char,
    name: *const c_char
) -> *const c_char {

    let config = cstr!(config, std::ptr::null());
    let password = cstr!(password, std::ptr::null());
    let mnemonic = cstr!(mnemonic, std::ptr::null());
    let name = cstr!(name, std::ptr::null());

    let result = recover_from_mnemonic(mnemonic, password, &config, name);
    let cstr = error!(result, std::ptr::null());
    let cstr = error!(CString::new(cstr), std::ptr::null());
    cstr.into_raw()
}

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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

fn _wallet_scan_outputs(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    start_height: u64,
    number_of_blocks: u64
) -> Result<*const c_char, Error> {
    let mut scan_result = String::from("");
    match wallet_scan_outputs(
        &wallet,
        keychain_mask,
        Some(start_height),
        Some(number_of_blocks)
    ) {
        Ok(scan) => {
            scan_result.push_str(&scan);
        },
        Err(err) => {
            return Err(err);
        },
    }

    let s = CString::new(scan_result).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

#[no_mangle]
pub unsafe extern "C" fn rust_create_tx(
    wallet: *const c_char,
    amount: *const c_char,
    to_address: *const c_char,
    secret_key_index: *const c_char,
    epicbox_config: *const c_char,
    min_confirmations: *const c_char,
) -> *const c_char {
    let wallet_ptr = CStr::from_ptr(wallet);
    let minimum_confirmations = CStr::from_ptr(min_confirmations);
    let minimum_confirmations: u64 = minimum_confirmations.to_str().unwrap().to_string().parse().unwrap();
    let amount = CStr::from_ptr(amount);
    let c_address = CStr::from_ptr(to_address);
    let key_index = CStr::from_ptr(secret_key_index);
    let epicbox_config = CStr::from_ptr(epicbox_config);

    let amount: u64 = amount.to_str().unwrap().to_string().parse().unwrap();
    let address = c_address.to_str().unwrap();
    let key_index: u32 = key_index.to_str().unwrap().to_string().parse().unwrap();
    let epicbox_config = epicbox_config.to_str().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();

    let listen = Listener {
        wallet_data: tuple_wallet_data.clone(),
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
        minimum_confirmations,
    ) {
        Ok(slate) => {
            //Spawn listener again
            listener_spawn(&listen);
            slate
        }, Err(e ) => {
            let error_msg = format!("Error {}", &e.to_string());
            let error_msg_ptr = CString::new(error_msg).unwrap();
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result

}

fn _create_tx(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    amount: u64,
    address: &str,
    _secret_key_index: u32,
    epicbox_config: &str,
    minimum_confirmations: u64,
) -> Result<*const c_char, Error> {
    let  mut message = String::from("");
    match tx_create(
        &wallet,
        keychain_mask.clone(),
        amount,
        minimum_confirmations,
        false,
        epicbox_config,
        address) {
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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)


}

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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

#[no_mangle]
pub unsafe extern "C" fn rust_tx_cancel(
    wallet: *const c_char,
    tx_id: *const c_char,
) -> *const c_char {

    let wallet_ptr = CStr::from_ptr(wallet);
    let tx_id = CStr::from_ptr(tx_id);
    let tx_id = tx_id.to_str().unwrap();
    let uuid = Uuid::parse_str(tx_id).map_err(|e| ErrorKind::GenericError(e.to_string())).unwrap();

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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

#[no_mangle]
pub unsafe extern "C" fn rust_get_chain_height(
    config: *const c_char,
) -> *const c_char {
    init_logger();
    let config = cstr!(config, std::ptr::null());
    let result = get_chain_height(config);
    let cstr = error!(result, std::ptr::null());
    let cstr = error!(CString::new(cstr.to_string()), std::ptr::null());
    cstr.into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn rust_delete_wallet(
    _wallet: *const c_char,
    config: *const c_char,
) -> *const c_char  {
    let config = cstr!(config, std::ptr::null());
    let result = delete_wallet(config);
    let cstr = error!(result, std::ptr::null());
    let cstr = error!(CString::new(cstr), std::ptr::null());
    cstr.into_raw()

    // let result = match _delete_wallet(
    //     _config,
    // ) {
    //     Ok(deleted) => {
    //         deleted
    //     }, Err(err) => {
    //         let error_msg = format!("Error deleting wallet from _delete_wallet in rust_delete_wallet {}", &err.to_string());
    //         let error_msg_ptr = CString::new(error_msg).unwrap();
    //         let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
    //         std::mem::forget(error_msg_ptr);
    //         ptr
    //     }
    // };
    // result
}

// fn _delete_wallet(
//     config: Config,
// ) -> Result<*const c_char, Error> {
//     let mut delete_result = String::from("");
//     match delete_wallet(config) {
//         Ok(deleted) => {
//             delete_result.push_str(&deleted);
//         },
//         Err(err) => {
//             return Err(err);
//         },
//     }
//     let s = CString::new(delete_result).unwrap();
//     let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
//     std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
//     Ok(p)
//
// }

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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

fn _get_wallet_address(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    index: u32,
    epicbox_config: &str
) -> Result<*const c_char, Error> {
    let address = get_wallet_address(&wallet, keychain_mask, index, epicbox_config);
    let s = CString::new(address).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

pub fn get_wallet_address(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    index: u32,
    epicbox_config: &str,
) -> String {

    let epicbox_conf = serde_json::from_str::<EpicboxConfig>(epicbox_config).unwrap();
    let api = Owner::new(wallet.clone());
    let address = api.get_public_address(keychain_mask.as_ref(), index).unwrap();
    format!("{}@{}", address.public_key, epicbox_conf.epicbox_domain)
}

#[no_mangle]
pub unsafe extern "C" fn rust_validate_address(
    address: *const c_char,
) -> i32 {
    init_logger();
    let address = cstr!(address);
    match validate_address(address) {
        true => 1,
        false => 0
    }
}

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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

pub fn create_wallet(config: &str, phrase: &str, password: &str, name: &str) -> Result<String, Error> {
    let wallet_pass = ZeroingString::from(password);
    let wallet_config = Config::from_str(config)?;
    let wallet = get_wallet(&wallet_config)?;
    let mut wallet_lock = wallet.lock();
    let lc = wallet_lock.lc_provider()?;
    let rec_phrase = ZeroingString::from(phrase.clone());
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

/*
    Get wallet info
    This contains wallet balances
*/
pub fn get_wallet_info(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    refresh_from_node: bool,
    min_confirmations: u64
) -> Result<WalletInfoFormatted, Error> {
    let api = Owner::new(wallet.clone());

    match api.retrieve_summary_info(keychain_mask.as_ref(), refresh_from_node, min_confirmations) {
        Ok((_, wallet_summary)) => {
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
            return  Err(e);
        }
    }

}

/*
    Recover wallet from mnemonic
*/
pub fn recover_from_mnemonic(mnemonic: &str, password: &str, config: &str, name: &str) -> Result<String, Error> {
    let config = Config::from_str(config)?;
    let wallet = get_wallet(&config)?;
    let mut w_lock = wallet.lock();
    let lc = w_lock.lc_provider()?;

    //Check if wallet seed directory exists, if not create
    match lc.wallet_exists(None)? {
        true => {
            lc.recover_from_mnemonic(
                ZeroingString::from(mnemonic), ZeroingString::from(password)
            )?;
            Ok("".to_string())
        }
        false => {
            lc.create_wallet(
                Some(&name),
                Some(ZeroingString::from(mnemonic)),
                32,
                ZeroingString::from(password),
                false,
            )?;
            Ok("".to_string())
        }
    }
}

/*
    Create a new wallet seed
*/
pub fn mnemonic() -> Result<String, stack_epic_keychain::mnemonic::Error> {
    let seed = create_seed(32);
    match mnemonic::from_entropy(&seed) {
        Ok(mnemonic_str) => {
            Ok(mnemonic_str)
        }, Err(e) => {
            return  Err(e);
        }
    }
}

fn create_seed(seed_length: u64) -> Vec<u8> {
    let mut seed: Vec<u8> = vec![];
    let mut rng = thread_rng();
    for _ in 0..seed_length {
        seed.push(rng.gen());
    }
    seed
}

/*
    Get wallet that will be used for calls to epic wallet
*/
fn get_wallet(config: &Config) -> Result<Wallet, Error> {
    let wallet_config = create_wallet_config(config.clone())?;
    let node_api_secret = get_first_line(wallet_config.node_api_secret_path.clone());
    let node_client = HTTPNodeClient::new(&wallet_config.check_node_api_http_addr, node_api_secret);
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
/*
    New wallet instance
*/
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

pub fn get_chain_height(config: &str) -> Result<u64, Error> {
    let config = Config::from_str(config)?;
    let wallet_config = create_wallet_config(config.clone())?;
    let node_api_secret = get_first_line(wallet_config.node_api_secret_path.clone());
    let node_client = HTTPNodeClient::new(&wallet_config.check_node_api_http_addr, node_api_secret);
    let chain_tip = match node_client.chain_height() {
        Ok(tip) => {
            tip
        }
        Err(err) => {
            return  Err(err);
        }
    };
    Ok(chain_tip.0)
}


/*

*/
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
        return Err(Error::from(ErrorKind::GenericError(format!(
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

    let last_block = start_height + number_of_blocks_to_scan;
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
        &None
    ) {
        Ok(info) => {


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
                match batch.save_last_confirmed_height(&parent_key_id, info.height) {
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
        }, Err(e) => {
            return  Err(e);
        }
    }
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

    for selection_strategy_is_use_all in vec![false].into_iter() {
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
                    selection_strategy_is_use_all,
                    total: slate.amount,
                    fee: slate.fee,

                });
            }, Err(e) => {
                return Err(e);
            }
        }
    }
    Ok(serde_json::to_string(&result).unwrap())
}

pub fn txs_get(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    refresh_from_node: bool,
) -> Result<String, Error> {
    let api = Owner::new(wallet.clone());
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
    address: &str
) -> Result<String, Error> {
    let owner_api = Owner::new(wallet.clone());
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
        message: None,
        send_args: Some(init_send_args),
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
    let api = Owner::new(wallet.clone());
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
    let api = Owner::new(wallet.clone());
    let uuid = Uuid::parse_str(tx_slate_id).map_err(|e| ErrorKind::GenericError(e.to_string())).unwrap();
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
    let config = Config::from_str(config_json)?;
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
        Err(Error::from(ErrorKind::WalletSeedDoesntExist))
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
                Error::from(ErrorKind::WalletSeedDoesntExist)
            );
        }
    }
    Ok("Wallet has been closed".to_owned())
}

pub fn validate_address(address: &str) -> bool {
    match EpicboxAddress::from_str(address) {
        Ok(_) => {
            true
        },
        _ => {
            false
        }
    }
}

pub fn delete_wallet(config: &str) -> Result<String, Error> {
    let config = Config::from_str(config)?;
    let mut result = String::from("");
    // get wallet object in order to use class methods
    let wallet = get_wallet(&config)?;
    //First close the wallet
    if let Ok(_) = close_wallet(&wallet) {
        let api = Owner::new(wallet.clone());
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
            Error::from(ErrorKind::GenericError(format!("{}", "Error closing wallet")))
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
    let api = Owner::new(wallet.clone());
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

#[derive(Debug, Clone)]
pub struct Listener {
    pub wallet_data: (i64, Option<SecretKey>),
    pub epicbox_config: String
}


impl Task for Listener {
    type Output = usize;

    fn run(&self, cancel_tok: &CancellationToken) -> Result<Self::Output, anyhow::Error> {
        let mut spins = 0;

        unsafe {
            let epicbox_conf = serde_json::from_str::<EpicboxConfig>(&self.epicbox_config.as_str()).unwrap();
            let wallet_data = &self.wallet_data;
            let wlt = wallet_data.clone().0;
            let sek_key = wallet_data.clone().1;
            ensure_wallet!(wlt, wallet);
            while !cancel_tok.cancelled() {
                let listener = EpicboxListenChannel::new().unwrap();
                listener.listen(
                    wallet.clone(),
                    Arc::new(Mutex::new(sek_key.clone())),
                    epicbox_conf.clone()
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

#[no_mangle]
pub unsafe extern "C" fn run_listener(
    wallet: *const c_char,
    epicbox_config: *const c_char,
) -> *const c_char  {
    let wallet_ptr = CStr::from_ptr(wallet);
    let epicbox_config = CStr::from_ptr(epicbox_config);
    let epicbox_config = epicbox_config.to_str().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let listen = Listener {
        wallet_data: tuple_wallet_data,
        epicbox_config: epicbox_config.parse().unwrap()
    };

    let _handle = listener_spawn(&listen);
    let msg = format!("START LISTENER {}", "LISTENER STARTED");
    let msg_ptr = CString::new(msg).unwrap();
    let ptr = msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(msg_ptr);
    ptr
}