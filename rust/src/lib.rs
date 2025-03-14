use std::cmp::Ordering;
use std::os::raw::{c_char};
use std::ffi::{CString, CStr};
use std::sync::Arc;
use std::path::{Path};
use rand::thread_rng;
use serde::{Deserialize, Serialize};
use rustc_serialize::json;
use uuid::Uuid;

use stack_test_epic_wallet_api::{self, Foreign, ForeignCheckMiddlewareFn, Owner};
use stack_test_epic_wallet_config::{WalletConfig};
use stack_test_epic_wallet_libwallet::api_impl::types::{InitTxArgs, InitTxSendArgs};
use stack_test_epic_wallet_libwallet::api_impl::owner;
use stack_test_epic_wallet_impls::{
    DefaultLCProvider, DefaultWalletImpl, HTTPNodeClient,
};

use ws::{
    CloseCode, Message, Error as WsError, ErrorKind as WsErrorKind,
    Result as WSResult, Sender, Handler
};

use stack_test_epic_keychain::mnemonic;
use stack_test_epic_wallet_util::stack_test_epic_core::global::ChainTypes;
use stack_test_epic_util::file::get_first_line;
use stack_test_epic_wallet_util::stack_test_epic_util::ZeroingString;
use stack_test_epic_util::Mutex;
use stack_test_epic_wallet_libwallet::{address, scan, slate_versions, wallet_lock, NodeClient, NodeVersionInfo, Slate, WalletInst, WalletLCProvider, Error, ErrorKind, TxLogEntry, TxLogEntryType};

use stack_test_epic_wallet_util::stack_test_epic_keychain::{Keychain, ExtKeychain};

use stack_test_epic_util::secp::rand::Rng;

use stack_test_epic_util::secp::key::{SecretKey, PublicKey};
use stack_test_epic_util::secp::{Secp256k1};

use stack_test_epicboxlib::types::{EpicboxAddress, EpicboxMessage, TxProofErrorKind};
use android_logger::FilterBuilder;
use std::env;
// mod main;

#[derive(Serialize, Deserialize, Clone, RustcEncodable, Debug)]
pub struct Config {
    pub wallet_dir: String,
    pub check_node_api_http_addr: String,
    pub chain: String,
    pub account: Option<String>,
    pub api_listen_port: u16,
    pub api_listen_interface: String
}

#[derive(Clone)]
struct Client {
    out: Sender,
}

#[derive(Serialize, Deserialize, Clone, RustcEncodable, Debug)]
pub struct EpicBoxConfig {
    domain: String,
    port: u16
}

impl EpicBoxConfig {
    fn from_str(json: &str) -> Result<Self, serde_json::error::Error> {
        let result = match  serde_json::from_str::<EpicBoxConfig>(json) {
            Ok(config) => {
                config
            }, Err(err) => {
                return  Err(err);
            }
        };
        Ok(result)
    }
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
            // let _ = $env.throw(serde_json::to_string(&format!("Wallet is NULL")).unwrap());
            println!("{}", "WALLET_IS_NOT_OPEN");
        }
        let $wallet = ($wallet_ptr as *mut Wallet).as_mut().unwrap();
    )
);

fn init_logger() {
    android_logger::init_once(
        AndroidConfig::default()
            .with_min_level(Level::Trace)
            .with_tag("libepiccash")
            .with_filter(FilterBuilder::new().parse("debug,epic-cash-wallet::crate=super").build()),
    );
}

impl Config {
    fn from_str(json: &str) -> Result<Self, serde_json::error::Error> {
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

static mut  SLATES_VECTOR: Vec<String> = Vec::new();
impl Handler for Client {

    fn on_message(&mut self, msg: Message) -> WSResult<()> {
        // Close the connection when we get a response from the server

        let msg = match msg {
            Message::Text(s) => { s }
            _ => { panic!() }
        };
        let parsed: serde_json::Value = serde_json::from_str(&msg).expect("Can't parse to JSON");
        if parsed["type"] == "Slate" {
            //Push into the vector
            unsafe {
                SLATES_VECTOR.push(msg);
            }
        }
        self.out.close(CloseCode::Normal)
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
use stack_test_epicboxlib::utils::crypto::{Hex, sign_challenge};

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

    let result = match _wallet_init(config, mnemonic, password, name) {
        Ok(created) => {
            created
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

#[no_mangle]
pub unsafe extern "C" fn get_mnemonic() -> *const c_char {
    let result = match _get_mnemonic() {
        Ok(phrase) => {
            phrase
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


fn _get_mnemonic() -> Result<*const c_char, stack_test_epic_keychain::mnemonic::Error> {
    let mut wallet_phrase = "".to_string();
    match mnemonic() {
        Ok(phrase) => {
            wallet_phrase.push_str(&phrase);
        },Err(e) => {
            return Err(e);
        }
    }
    let s = CString::new(wallet_phrase).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

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
            Error::from(ErrorKind::GenericError(format!("{}", e.to_string())))
        )}
    };

    let str_config = match config.to_str() {
        Ok(str_conf) => {str_conf}, Err(e) => {return Err(
            Error::from(ErrorKind::GenericError(format!("{}", e.to_string())))
        )}
    };

    let phrase = match mnemonic.to_str() {
        Ok(str_phrase) => {str_phrase}, Err(e) => {return Err(
            Error::from(ErrorKind::GenericError(format!("{}", e.to_string())))
        )}
    };

    let str_name = match name.to_str() {
        Ok(str_name) => {str_name}, Err(e) => {return Err(
            Error::from(ErrorKind::GenericError(format!("{}", e.to_string())))
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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}


#[no_mangle]
pub unsafe extern "C"  fn rust_open_wallet(
    config: *const c_char,
    password: *const c_char,
) -> *const c_char {
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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

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
            return Err(Error::from(ErrorKind::GenericError(format!(
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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
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
pub unsafe extern "C" fn rust_encrypt_slate(
    wallet: *const c_char,
    to_address: *const c_char,
    secret_key_index: *const c_char,
    epicbox_config: *const c_char,
    slate: *const c_char,
) -> *const c_char {

    let wallet_ptr = CStr::from_ptr(wallet);
    let c_address = CStr::from_ptr(to_address);
    let key_index = CStr::from_ptr(secret_key_index);
    let epicbox_config = CStr::from_ptr(epicbox_config);
    let slate = CStr::from_ptr(slate);

    let address = c_address.to_str().unwrap();
    let key_index: u32 = key_index.to_str().unwrap().to_string().parse().unwrap();
    let epicbox_config = epicbox_config.to_str().unwrap();
    let slate = slate.to_str().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _encrypt_slate(
        &wallet,
        sek_key,
        address,
        key_index,
        epicbox_config,
        slate
    ) {
        Ok(post_late_request) => {
            post_late_request
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

fn _encrypt_slate(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    address: &str,
    secret_key_index: u32,
    epicbox_config: &str,
    slate: &str,
) -> Result<*const c_char, Error>{
    let epicbox_conf = match EpicBoxConfig::from_str(&epicbox_config.to_string()) {
        Ok(config) => {
            config
        }, Err(err) => {
            return Err(Error::from(ErrorKind::GenericError(format!(
                "epicbox config error {}",
                err.to_string()
            ))))
        }
    };

    let key_pair = match get_wallet_secret_key_pair(
        wallet, keychain_mask, secret_key_index
    ) {
        Ok(sec_pub_pair) => {
            sec_pub_pair
        }
        Err(err) => {
            return Err(err);
        }
    };
    let slate_msg = build_post_slate_request(
        address,
        key_pair,
        slate.to_string(),
        epicbox_conf);

    let s = CString::new(slate_msg).unwrap();
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
    secret_key_index: u32,
    epicbox_config: &str,
    minimum_confirmations: u64,
) -> Result<*const c_char, Error> {
    let epicbox_conf = match EpicBoxConfig::from_str(&epicbox_config.to_string()) {
        Ok(config) => {
            config
        }, Err(err) => {
            return Err(Error::from(ErrorKind::GenericError(format!(
                "EPICBOX_CONFIG_ERROR {}",
                err.to_string()
            ))))
        }
    };

    let  mut message = String::from("");
    match tx_create(
        &wallet,
        keychain_mask.clone(),
        amount,
        minimum_confirmations,
        false) {
        Ok(slate) => {
            //Get Secret key at given Index, build epicbox request
            let key_pair = get_wallet_secret_key_pair(
                &wallet, keychain_mask, secret_key_index
            ).unwrap();
            let slate_msg = build_post_slate_request(
                address,
                key_pair,
                slate.clone(),
                epicbox_conf.clone());

            let create_response = (&slate, &slate_msg);
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
pub unsafe extern "C" fn rust_decrypt_unprocessed_slates(
    wallet: *const c_char,
    secret_key_index: *const c_char,
    slate: *const c_char,
) -> *const c_char  {
    let wallet_ptr = CStr::from_ptr(wallet);
    let key_index = CStr::from_ptr(secret_key_index);
    let slate = CStr::from_ptr(slate);

    let key_index: u32 = key_index.to_str().unwrap().to_string().parse().unwrap();
    let slate = slate.to_str().unwrap();
    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _decrypt_unprocessed_slates(
        wallet,
        sek_key,
        key_index,
        slate,
    ) {
        Ok(pending_slates) => {
            pending_slates
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

fn _decrypt_unprocessed_slates(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    secret_key_index: u32,
    slates: &str
) -> Result<*const c_char, Error> {

    let key_pair = get_wallet_secret_key_pair(
        wallet, keychain_mask, secret_key_index
    ).unwrap();
    let mut pending_slates = "".to_string();
    let slates_to_lower = slates.to_lowercase();
    if slates_to_lower.contains("error") || slates_to_lower.is_empty() {
        return  Err(Error::from(ErrorKind::GenericError(format!(
            "{}",
            "Unable to format slates, please check data"
        ))));
    }
    match decrypt_epicbox_slates(key_pair, &slates) {
        Ok(decrypted) => {
            let str_slates = serde_json::to_string(&decrypted).unwrap();
            pending_slates.push_str(&str_slates);
        }, Err(e) => {
            return Err(e);
        }
    };
    let s = CString::new(pending_slates).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}


#[no_mangle]
pub unsafe extern "C" fn rust_process_pending_slates(
    wallet: *const c_char,
    slates: *const c_char,
) -> *const c_char  {
    let wallet_ptr = CStr::from_ptr(wallet);
    let slates = CStr::from_ptr(slates);
    let pending_slates = slates.to_str().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _process_pending_slates(
        wallet,
        sek_key,
        pending_slates
    ) {
        Ok(processed_slates) => {
            processed_slates
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

fn _process_pending_slates(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    slates: &str
) -> Result<*const c_char, Error> {

    let mut processed_slates = "".to_string();
    match process_received_slates(
        wallet,
        keychain_mask,
        slates
    ) {
        Ok(slates) => {
            processed_slates.push_str(&slates);
        }, Err(e) => {
            return  Err(e);
        }
    }
    let s = CString::new(processed_slates).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

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
            let ptr = error_msg_ptr.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(error_msg_ptr);
            ptr
        }
    };
    result
}

fn _get_chain_height(config: *const c_char) -> Result<*const c_char, Error> {
    debug!("{}", "GETTING_CHAIN_HEIGHT");
    let c_config = unsafe { CStr::from_ptr(config) };
    let str_config = c_config.to_str().unwrap();
    let mut chain_height = "".to_string();
    match get_chain_height(&str_config) {
        Ok(chain_tip) => {
            debug!("CHAIN_HEIGHT {}", chain_tip);
            chain_height.push_str(&chain_tip.to_string());
        },
        Err(e) => {
            debug!("CHAIN_HEIGHT_ERROR {}", e.to_string());
            return Err(e);
        },
    }
    let s = CString::new(chain_height).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

#[no_mangle]
pub unsafe extern "C" fn rust_delete_wallet(
    wallet: *const c_char,
) -> *const c_char  {
    let wallet_ptr = CStr::from_ptr(wallet);
    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;
    ensure_wallet!(wlt, wallet);
    let result = match _delete_wallet(
        wallet
    ) {
        Ok(deleted) => {
            deleted
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

fn _delete_wallet(
    wallet: &Wallet,
) -> Result<*const c_char, Error> {

    let mut delete_result = String::from("");
    match delete_wallet(wallet) {
        Ok(deleted) => {
            delete_result.push_str(&deleted);
        },
        Err(err) => {
            return Err(err);
        },
    }
    let s = CString::new(delete_result).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)

}

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

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct EpicboxInfo {
    pub address: String,
    pub public_key: String,
    pub secret_key: String,
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
    let epicbox_conf = match EpicBoxConfig::from_str(&epicbox_config.to_string()) {
        Ok(config) => {
            config
        }, Err(e) => {
            return Err(Error::from(ErrorKind::GenericError(format!(
                "{}",
                "Unable to get epicbox config"
            ))))
        }
    };

    let key_pair = get_wallet_secret_key_pair(wallet, keychain_mask, index).unwrap();
    let wallet_address = get_epicbox_address(key_pair.1, &epicbox_conf.domain, Some(epicbox_conf.port)).public_key;
    let s = CString::new(wallet_address).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

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
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
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

#[no_mangle]
pub unsafe extern "C" fn rust_post_slate_to_node(
    wallet: *const c_char,
    tx_slate_id: *const c_char,
) -> *const c_char {
    let wallet_ptr = CStr::from_ptr(wallet);
    let tx_slate_id = CStr::from_ptr(tx_slate_id);
    let tx_slate_id = tx_slate_id.to_str().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);

    let result = match _post_slate_to_node(
        wallet,
        sek_key,
        tx_slate_id
    ) {
        Ok(posted) => {
            posted
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

pub fn create_wallet(config: &str, phrase: &str, password: &str, name: &str) -> Result<String, Error> {
    let wallet_pass = ZeroingString::from(password);
    let wallet_config = match Config::from_str(&config) {
        Ok(config) => {
            config
        }, Err(e) => {
            return  Err(Error::from(ErrorKind::GenericError(format!(
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
                ErrorKind::GenericError(
                    format!("{}", err.to_string())
                )
            ));
        }
    };

    Ok((sec_key, pub_key))
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

    //First check if wallet seed directory exists, if not create
    if let Ok(exists_wallet_seed) = lc.wallet_exists(None) {
        if exists_wallet_seed {
            match lc.recover_from_mnemonic(
                ZeroingString::from(mnemonic), ZeroingString::from(password)
            ) {
                Ok(_) => {
                    return  Ok(());
                }
                Err(e) => {
                    return  Err(e);
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
                    return  Ok(());
                }
                Err(e) => {
                    return  Err(e);
                }
            }
        }
    }
    Ok(())
}

/*
    Create a new wallet seed
*/
pub fn mnemonic() -> Result<String, stack_test_epic_keychain::mnemonic::Error> {
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
    let wallet_config = match create_wallet_config(config.clone()) {
        Ok(conf) => {
            conf
        } Err(e) => {
            return Err(e);
        }
    };
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
    let config = match Config::from_str(&config.to_string()) {
        Ok(config) => {
            config
        }, Err(e) => {
            return Err(Error::from(ErrorKind::GenericError(format!(
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
) -> Result<String, Error> {
    let owner_api = Owner::new(wallet.clone());
    let accounts = match  owner_api.accounts(keychain_mask.as_ref()) {
        Ok(accounts_list) => {
            accounts_list
        }, Err(e) => {
            return  Err(e);
        }
    };
    let account = &accounts[0].label;

    let args = InitTxArgs {
        src_acct_name: Some(account.clone()),
        amount,
        minimum_confirmations,
        max_outputs: 500,
        num_change_outputs: 1,
        selection_strategy_is_use_all,
        message: None,
        ..Default::default()
    };

    match owner_api.init_send_tx(keychain_mask.as_ref(), args) {
        Ok(slate)=> {
            //Lock slate uptputs
            match owner_api.tx_lock_outputs(
                keychain_mask.as_ref(),
                &slate,
                0
            ) {
                Ok(_) => {
                    ()
                }
                Err(err) => {
                    return  Err(err);
                }
            };
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

#[no_mangle]
pub unsafe extern "C" fn subscribe_request(
    wallet: *const c_char,
    secret_key_index: *const c_char,
    epicbox_config: *const c_char,
) -> *const c_char  {
    let wallet_ptr = CStr::from_ptr(wallet);
    let key_index = CStr::from_ptr(secret_key_index);
    let epicbox_config = CStr::from_ptr(epicbox_config);
    let epicbox_config = epicbox_config.to_str().unwrap();
    let key_index: u32 = key_index.to_str().unwrap().to_string().parse().unwrap();

    let wallet_data = wallet_ptr.to_str().unwrap();
    let tuple_wallet_data: (i64, Option<SecretKey>) = serde_json::from_str(wallet_data).unwrap();
    let wlt = tuple_wallet_data.0;
    let sek_key = tuple_wallet_data.1;

    ensure_wallet!(wlt, wallet);


    let result = match _subscribe_request(
        wallet,
        sek_key,
        key_index,
        epicbox_config,
    ) {
        Ok(subscribe_request) => {
            subscribe_request
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

fn _subscribe_request(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    secret_key_index: u32,
    epicbox_config: &str,
) -> Result<*const c_char, Error> {
    let key_pair = get_wallet_secret_key_pair(
        wallet, keychain_mask, secret_key_index
    ).unwrap();
    let epicbox_conf = match EpicBoxConfig::from_str(&epicbox_config.to_string()) {
        Ok(config) => {
            config
        }, Err(e) => {
            return Err(Error::from(ErrorKind::GenericError(format!(
                "{}",
                "Unable to get epicbox config"
            ))))
        }
    };

    let subscribe_request = _build_subscribe_request(
        key_pair,
        epicbox_conf.clone()
    );
    let s = CString::new(subscribe_request).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}

fn _post_slate_to_node(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    tx_slate_id: &str,
) -> Result<*const c_char, Error> {

    let  mut tx_post_message = String::from("");
    match tx_post(wallet, keychain_mask, tx_slate_id) {
        Ok(posted) => {
            tx_post_message.push_str(&posted);
        }, Err(e) => {
            tx_post_message.push_str(&e.to_string());
        }
    }
    let s = CString::new(tx_post_message).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    Ok(p)
}



pub fn decrypt_epicbox_slates(
    secret_pub_key_pair: (SecretKey, PublicKey), encrypted_slates: &str
) -> Result<Vec<String>, Error>{
    let messages: Vec<String> = serde_json::from_str(&encrypted_slates).unwrap();
    let mut decrypted_slates: Vec<String> = Vec::new();
    for message in messages.into_iter() {
        let parsed: serde_json::Value = serde_json::from_str(&message).expect("Can't parse to JSON");
        match  decrypt_message(&secret_pub_key_pair.0, parsed.clone()) {
            Ok(decrypted_msg) => {
                let sender_address = parsed.get("from").unwrap().as_str().unwrap();
                let return_data = (decrypted_msg, sender_address);

                decrypted_slates.push(serde_json::to_string(&return_data).unwrap());
            }, Err(e) => {
                let error_msg = format!("Error : {}", e.to_string());
                decrypted_slates.push(error_msg);
            }
        };
    }
    Ok(decrypted_slates)

}

pub fn process_received_slates(
    wallet: &Wallet, keychain_mask: Option<SecretKey>, message: &str
) -> Result<String, Error> {

    let mut process_result = "".to_string();
    let process = process_epic_box_slate(&wallet, keychain_mask.clone(),  &message);
    match process {
        Ok(slate) => {
            let msg_tuple: (String, String) =  serde_json::from_str(&message).unwrap();
            let transaction: Vec<TxLogEntry> = serde_json::from_str(&msg_tuple.0).unwrap();

            match transaction[0].tx_type {
                TxLogEntryType::TxSent => {
                    //Push into receive array
                    let message_status = format!(r#"{{"status": "PendingProcessing"}}"#);
                    let return_data = (message_status, slate);
                    process_result.push_str(&serde_json::to_string(&return_data).unwrap());
                },
                TxLogEntryType::TxReceived =>  {
                    let message_status = format!(r#"{{"status": "Finalised"}}"#);
                    let return_data = (message_status, slate);
                    process_result.push_str(&serde_json::to_string(&return_data).unwrap());
                },
                _ => {}
            }
        },
        Err(err) => {
            return  Err(err);
        }
    };
    Ok(process_result)
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

/*
    Check slate version
*/
fn check_middleware(
    name: ForeignCheckMiddlewareFn,
    node_version_info: Option<NodeVersionInfo>,
    slate: Option<&Slate>,
) -> Result<(), Error> {
    match name {
        // allow coinbases to be built regardless
        ForeignCheckMiddlewareFn::BuildCoinbase => Ok(()),
        _ => {
            let mut bhv = 3;
            if let Some(n) = node_version_info {
                bhv = n.block_header_version;
            }
            if let Some(s) = slate {
                if bhv > 4
                    && s.version_info.block_header_version
                    < slate_versions::EPIC_BLOCK_HEADER_VERSION
                {
                    Err(ErrorKind::Compatibility(
                        "Incoming Slate is not compatible with this wallet. Please upgrade the node or use a different one."
                            .into(),
                    ))?;
                }
            }
            Ok(())
        }
    }
}

pub fn tx_receive(wallet: &Wallet, keychain_mask: Option<SecretKey>, account: &str, str_slate: &str) -> Result<String, Error> {
    let slate = match Slate::deserialize_upgrade(str_slate) {
        Ok(result) => {
            result
        }
        Err(err) => {
            return Err(err);
        }
    };
    let owner_api = Owner::new(wallet.clone());
    let foreign_api = Foreign::new(
        wallet.clone(),
        keychain_mask.clone(),
        Some(check_middleware));

    match foreign_api.receive_tx(&slate, Some(&account), None) {
        Ok(slate)=> {
            let txs = match owner_api.retrieve_txs(
                keychain_mask.as_ref(),
                false,
                None,
                Some(slate.id)
            ) {
                Ok(slate_txs) => {
                    slate_txs
                }, Err(e) => {
                    return  Err(e);
                }
            };

            let final_result = (
                serde_json::to_string(&txs.1).unwrap(),
                serde_json::to_string(&slate).unwrap()
            );
            Ok(serde_json::to_string(&final_result).unwrap())
        },
        Err(e)=> {
            return  Err(e);
        }
    }
}

/*

*/
pub fn tx_finalize(
    wallet: &Wallet, keychain_mask: Option<SecretKey>, str_slate: &str
) -> Result<String, Error> {
    let slate = match Slate::deserialize_upgrade(str_slate) {
        Ok(result) => {
            result
        }
        Err(err) => {
            return  Err(err);
        }
    };
    let owner_api = Owner::new(wallet.clone());
    let response = owner_api.finalize_tx(keychain_mask.as_ref(), &slate);
    match response {
        Ok(slate)=> {
            let txs = match owner_api.retrieve_txs(
                keychain_mask.as_ref(),
                false,
                None,
                Some(slate.id)
            ) {
                Ok(transactions) => {
                    transactions
                }, Err(e) => {
                    return Err(e);
                }
            };
            let final_result = (
                serde_json::to_string(&txs.1).unwrap(),
                serde_json::to_string(&slate).unwrap()
            );
            Ok(serde_json::to_string(&final_result).unwrap())
        },
        Err(e)=> {
            return  Err(e);
        }
    }
}

/*
    Post transaction to the node after finalising
*/
pub fn tx_post(
    wallet: &Wallet, keychain_mask: Option<SecretKey>, tx_slate_id: &str
) -> Result<String, Error> {
    let owner_api = Owner::new(wallet.clone());
    let tx_uuid =
        Uuid::parse_str(tx_slate_id).map_err(|e| ErrorKind::GenericError(e.to_string()))?;
    let (_, txs) = match owner_api.retrieve_txs(
        keychain_mask.as_ref(),
        false,
        None,
        Some(tx_uuid.clone())
    ) {
        Ok(result) => {
            result
        }
        Err(err) => {
            return  Err(err);
        }
    };
    println!("TX IS ::: {:?}", txs[0]);
    if txs[0].confirmed {
        return Err(Error::from(ErrorKind::GenericError(format!(
            "Transaction with id {} is already confirmed. Not posting.",
            tx_slate_id
        ))));
    }

    let stored_tx = owner_api.get_stored_tx(
        keychain_mask.as_ref(),
        &txs[0])?;
    match stored_tx {
        Some(stored_tx) => {
            match owner_api.post_tx(keychain_mask.as_ref(), &stored_tx, true) {
                Ok(()) => {
                    Ok("tx_posted_to_node".to_owned())
                },
                Err(err)=> {
                    return Err(err);
                }
            }
        }
        None => Err(Error::from(ErrorKind::GenericError(format!(
            "Transaction with id {} does not have transaction data. Not posting.",
            tx_slate_id
        )))),
    }
}

/*
    Get epic box address for receiving slates
 */
pub fn get_epicbox_address(
    public_key: PublicKey,
    domain: &str,
    port: Option<u16>) -> EpicboxAddress
{
    let domain = domain.to_string();
    EpicboxAddress::new(public_key, Some(domain), port)
}

pub fn derive_public_key_from_address(address: &str) -> PublicKey {
    let address = EpicboxAddress::from_str(address).unwrap();
    let public_key = address.public_key().unwrap();
    public_key
}

pub fn build_post_slate_request(
    receiver_address: &str,
    secret_pub_key_pair: (SecretKey, PublicKey),
    tx: String,
    epicbox_config: EpicBoxConfig
) -> String {
    let address_sender = get_epicbox_address(
        secret_pub_key_pair.1,
        &epicbox_config.domain,
        Some(epicbox_config.port)
    );

    let address_receiver = EpicboxAddress::from_str(receiver_address).unwrap();
    let pub_key_receiver = address_receiver.public_key().unwrap();
    let address_receiver = get_epicbox_address(
        pub_key_receiver, &epicbox_config.domain, Some(epicbox_config.port));

    let mut challenge = String::new();
    let message = EpicboxMessage::new(
        tx,
        &address_receiver.clone(),
        &address_receiver.public_key().unwrap(),
        &secret_pub_key_pair.0
    ).map_err(|_| WsError::new(WsErrorKind::Protocol, "could not encrypt slate!")).unwrap();
    let message_ser = serde_json::to_string(&message).unwrap();

    let to_address = format!("{}", address_receiver.public_key);
    let from_address = format!("{}", address_sender.public_key);
    challenge.push_str(&message_ser);
    let signature = sign_challenge(&challenge, &secret_pub_key_pair.0).unwrap().to_hex();
    let json_request = format!(r#"{{"type": "PostSlate", "from": "{}", "to": "{}", "str": {}, "signature": "{}"}}"#,
                               from_address,
                               to_address,
                               json::as_json(&message_ser),
                               signature);

    json_request
}

pub fn _build_subscribe_request(
    secret_pub_key_pair: (SecretKey, PublicKey)
    , epicbox_config: EpicBoxConfig
) -> String {
    let address = get_epicbox_address(secret_pub_key_pair.1, &epicbox_config.domain, Some(epicbox_config.port));

    // The signed message binds to the request type (subscription) and the intended address (with domain)
    // WARNING: This request does not bind to _any_ other context, and could be vulnerable to replay
    let challenge = String::from(format!("SubscribeRequest_{}", address.public_key));

    let signature = sign_challenge(&challenge, &secret_pub_key_pair.0).unwrap().to_hex();
    let subscribe_str = format!(r#"{{"type": "Subscribe", "address": "{}", "signature": "{}"}}"#, address.public_key, signature);
    subscribe_str
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
    Decrypt slate retreived from epic box
*/
pub fn decrypt_message(receiver_key: &SecretKey, msg_json: serde_json::Value) -> Result<String, Error> {
    let sender_address = msg_json.get("from").unwrap().as_str().unwrap();
    let sender_public_key: PublicKey = EpicboxAddress::from_str(sender_address).unwrap().public_key()
        .unwrap();

    let message = msg_json.get("str").unwrap().as_str().unwrap();
    let encrypted_message: EpicboxMessage =
        serde_json::from_str(message).map_err(|_| TxProofErrorKind::ParseEpicboxMessage).unwrap();

    let key = encrypted_message.key(&sender_public_key, &receiver_key).unwrap();
    let decrypted_message = match encrypted_message.decrypt_with_key(&key) {
        Ok(decrypted) => {
            decrypted
        }, Err(e) => {
            format!("Error {}", e.to_string())
        }
    };

    Ok(decrypted_message)
}

/*
    Process received slate from Epicbox, and return processed slate for posting
*/
pub fn process_epic_box_slate(wallet: &Wallet, keychain_mask: Option<SecretKey>, slate_info: &str
) -> Result<String, Error> {
    let msg_tuple: (String, String) =  serde_json::from_str(&slate_info).unwrap();
    let transaction: Vec<TxLogEntry> = serde_json::from_str(&msg_tuple.0).unwrap();

    match transaction[0].tx_type {
        TxLogEntryType::TxSent => {
            match tx_receive(&wallet, keychain_mask.clone(), "default", &msg_tuple.1) {
                Ok(slate) => {
                    Ok(slate)
                },
                Err(e) => {
                    return Err(e);
                }
            }
        },
        TxLogEntryType::TxReceived =>  {
            let finalize = tx_finalize(&wallet, keychain_mask.clone(), &msg_tuple.1);
            match finalize {
                Ok(str_slate) => {
                    Ok(str_slate)
                },
                Err(e)=> {
                    Err(e)
                }
            }
        },
        TxLogEntryType::ConfirmedCoinbase => {
            Err(Error::from(ErrorKind::GenericError(format!(
                "The provided slate has already been confirmed, not processed.",
            ))))
        },
        _ => {
            Err(Error::from(ErrorKind::GenericError(format!(
                "The provided slate could not be processed, cancelled by user.",
            ))))
        }
    }

}

/*

*/
pub fn open_wallet(config_json: &str, password: &str) -> Result<(Wallet, Option<SecretKey>), Error> {
    let config = match Config::from_str(&config_json.to_string()) {
        Ok(config) => {
            config
        }, Err(e) => {
            return Err(Error::from(ErrorKind::GenericError(format!(
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
        Err(Error::from(ErrorKind::WalletSeedDoesntExist))
    }
}


pub fn close_wallet(wallet: &Wallet) -> Result<String, Error> {
    let mut wallet_lock = wallet.lock();
    let lc = wallet_lock.lc_provider()?;
    if let Ok(open_wallet) = lc.wallet_exists(None) {
        if open_wallet {
            lc.close_wallet(None)?;
        }
    }
    Ok("Wallet has been closed".to_owned())
}

pub fn validate_address(address: &str) -> bool {
    let address = EpicboxAddress::from_str(address);
    match address {
        Ok(_) => {
            true
        },
        _ => {
            false
        }
    }
}

pub fn delete_wallet(wallet: &Wallet) -> Result<String, Error> {
    //First close the wallet
    let mut result = String::from("");
    if let Ok(closed) = close_wallet(&wallet) {
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
        return  return Err(
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
    let initSendArgs = InitTxSendArgs {
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
        send_args: Some(initSendArgs),
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
