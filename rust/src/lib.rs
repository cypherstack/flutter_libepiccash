use std::os::raw::{c_char, c_int, c_uint};
use std::ffi::{CString, CStr};
use std::collections::HashMap;
use std::sync::Arc;
use std::path::{Path, PathBuf};
use rand::thread_rng;
use serde::{Deserialize, Serialize};
use rustc_serialize::json;
use serde_json::json as serde_json;
use serde_json::to_string;
use uuid::Uuid;

use stack_test_epic_wallet_api::{self, Foreign, ForeignCheckMiddlewareFn, Owner};
use stack_test_epic_wallet_config::{WalletConfig};
use stack_test_epic_wallet_libwallet::api_impl::types::InitTxArgs;
use stack_test_epic_wallet_libwallet::api_impl::owner;
use stack_test_epic_wallet_impls::{
    DefaultLCProvider, DefaultWalletImpl, HTTPNodeClient, HttpSlateSender, SlateSender,
};

use futures::executor::block_on;
use url::Url;
use tungstenite::{connect, Message, WebSocket};
use ws::{
    CloseCode, Error as WsError, ErrorKind as WsErrorKind, Handler, Handshake,
    Result as WsResult, Sender,
};



use stack_test_epic_keychain::mnemonic;
use stack_test_epic_wallet_util::stack_test_epic_core::global::ChainTypes;
use stack_test_epic_core::global;
use stack_test_epic_util::file::get_first_line;
use stack_test_epic_wallet_util::stack_test_epic_util::ZeroingString;
use stack_test_epic_util::Mutex;
use stack_test_epic_wallet_libwallet::{
    address, scan, slate_versions, wallet_lock, NodeClient,
    NodeVersionInfo, Slate, WalletInst, WalletLCProvider,
    WalletInfo, Error, ErrorKind
};

use stack_test_epicboxlib::utils::secp::{SecretKey, PublicKey, Secp256k1};
use stack_test_epic_wallet_util::stack_test_epic_keychain::{Keychain, ExtKeychain};
use stack_test_epic_wallet_libwallet::api_impl::owner_updater::StatusMessage;
// use epic_keychain::{Keychain, ExtKeychain};

use stack_test_epic_util::secp::rand::Rng;
use stack_test_epic_util::to_hex;

use stack_test_epicboxlib::types::{EpicboxAddress, EpicboxError, version_bytes, EpicboxMessage};

#[derive(Serialize, Deserialize, Clone, RustcEncodable, Debug)]
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

impl Config {
    fn from_str(json: &str) -> Result<Self, Error> {
        Ok(serde_json::from_str::<Config>(json).unwrap())
    }
}

const EPIC_BOX_ADDRESS: &str = "5.9.155.102";
const EPIC_BOX_PORT: u16 = 13420;



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

use log::Level;
use android_logger::Config as AndroidConfig;
use stack_test_epic_wallet_util::stack_test_epic_api::response;
use stack_test_epicboxlib::utils::crypto::{Hex, sign_challenge};
use tokio_tungstenite::WebSocketStream;
use tungstenite::client::AutoStream;

/*
    Create a new wallet
*/

pub fn init_logger() {
    android_logger::init_once(
        AndroidConfig::default().with_min_level(Level::Trace),
    );
}


#[no_mangle]
pub unsafe extern "C" fn wallet_init(
    config: *const c_char,
    mnemonic: *const c_char,
    password: *const c_char,
    name: *const c_char

) -> *const c_char {

    init_logger();
    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_mnemonic = unsafe { CStr::from_ptr(mnemonic) };
    let c_password = unsafe { CStr::from_ptr(password) };
    let c_name = unsafe { CStr::from_ptr(name) };

    let input_pass = c_password.to_str().unwrap();
    let input_conf = c_conf.to_str().unwrap();

    debug!("{}", input_conf.to_string());

    let wallet_pass = ZeroingString::from(input_pass.to_string());
    let wallet_config = Config::from_str(&input_conf.to_string()).unwrap();
    let phrase = c_mnemonic.to_str().unwrap().to_string();
    let wallet_name = c_name.to_str().unwrap().to_string();

    let wallet = get_wallet(&wallet_config).unwrap();
    let mut wallet_lock = wallet.lock();
    let lc = wallet_lock.lc_provider().unwrap();
    let rec_phrase = ZeroingString::from(phrase.clone());
    let mut createMsg = String::from("");

    match lc.create_wallet(
        Some(&wallet_name),
        Some(rec_phrase),
        32,
        wallet_pass.clone(),
        false,
    ) {
        Ok(sk) => {
            debug!("{}", "Wallet created");
            createMsg.push_str("created");
        },
        Err(e) => {
            createMsg.push_str(&e.to_string());
            // let msg = format!("Wallet Exists inside epic-wallet at {}/wallet_data", config.wallet_dir);
        },
    }

    let s = CString::new(createMsg).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
}

#[no_mangle]
pub unsafe extern "C" fn get_mnemonic() -> *const c_char {
    let wallet_phrase = mnemonic().unwrap();
    let s = CString::new(wallet_phrase).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
}

/*
    Get wallet info
    This contains wallet balances
*/
#[no_mangle]
pub unsafe extern "C"  fn rust_wallet_balances(
    config: *const c_char,
    password: *const c_char
) -> *const c_char {

    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };

    let input_pass = c_password.to_str().unwrap();
    let input_conf = c_conf.to_str().unwrap();

    debug!("{}", input_pass);
    debug!("{}", input_conf);

    let wallet = open_wallet(&input_conf, &input_pass).unwrap();
    let info = get_wallet_info(&wallet, true, 10).unwrap();

    let string_info = serde_json::to_string(&info).unwrap();

    let s = CString::new(string_info).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
}

#[no_mangle]
pub unsafe extern "C"  fn rust_recover_from_mnemonic(
    config: *const c_char,
    password: *const c_char,
    mnemonic: *const c_char,
    name: *const c_char
) -> *const c_char {
    init_logger();
    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };
    let c_mnemonic = unsafe { CStr::from_ptr(mnemonic) };
    let c_name = unsafe { CStr::from_ptr(name) };

    let input_conf = c_conf.to_str().unwrap();

    let wallet_pass = c_password.to_str().unwrap().to_string();
    let wallet_config = Config::from_str(&input_conf.to_string()).unwrap();
    let phrase = c_mnemonic.to_str().unwrap().to_string();
    let name = c_name.to_str().unwrap();

    let mut recover_response = "".to_string();
    let recover = recover_from_mnemonic(&phrase, &wallet_pass, &wallet_config, &name);
    match recover {
        Ok(recover)=> {
            recover_response.push_str("recovered");
        },
        Err(e)=> {
            recover_response.push_str(&e.to_string());
        }
    }

    let s = CString::new(recover_response).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p

}

#[no_mangle]
pub unsafe extern "C"  fn rust_wallet_phrase(
    config: *const c_char,
    password: *const c_char,
) -> *const c_char {
    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };

    let input_pass = c_password.to_str().unwrap().to_string();
    let input_conf = c_conf.to_str().unwrap().to_string();
    let wallet_config = Config::from_str(&input_conf).unwrap();

    let phrase = wallet_phrase(&input_pass, wallet_config).unwrap();
    let s = CString::new(phrase).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
}

#[no_mangle]
pub unsafe extern "C" fn rust_wallet_scan_outputs(
    config: *const c_char,
    password: *const c_char
) -> *const c_char {

    debug!("{}", "Calling wallet scanner");

    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };
    let input_pass = c_password.to_str().unwrap();
    let input_conf = c_conf.to_str().unwrap();
    let wallet = open_wallet(&input_conf, &input_pass).unwrap();
    let pmmr_range = wallet_pmmr_range(&wallet).unwrap();

    //Scan wallet
    let scan = wallet_scan_outputs(&wallet, Some(pmmr_range.0)).unwrap();

    let s = CString::new("").unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
}

#[no_mangle]
pub unsafe extern "C" fn rust_create_tx(
    config: *const c_char,
    password: *const c_char,
    amount: *const c_char,
    minimum_confirmations: *const c_char,
) -> *const c_char {

    init_logger();
    debug!("Calling logger");
    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };
    let amount = unsafe { CStr::from_ptr(amount) };
    let minimum_confirmations = unsafe { CStr::from_ptr(minimum_confirmations) };

    let input_pass = c_password.to_str().unwrap();
    let input_conf = c_conf.to_str().unwrap();
    let amount = amount.to_str().unwrap().to_string();
    let minimum_confirmations = minimum_confirmations.to_str().unwrap().to_string();

    let amount: u64 = amount.parse().unwrap();
    let minimum_confirmations: u64 = minimum_confirmations.parse().unwrap();

    let wallet = open_wallet(input_conf, input_pass).unwrap();
    let json_slate = tx_create(&wallet, amount, minimum_confirmations, true).unwrap();
    debug!("{}", "Tx debug below:::::");
    debug!("{}", json_slate);

    let s = CString::new(json_slate).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p

}

#[no_mangle]
pub unsafe extern "C" fn rust_txs_get(
    config: *const c_char,
    password: *const c_char,
    minimum_confirmations: *const c_char
) -> *const c_char {

    init_logger();
    let c_conf = unsafe { CStr::from_ptr(config) };
    let c_password = unsafe { CStr::from_ptr(password) };
    let minimum_confirmations = unsafe { CStr::from_ptr(minimum_confirmations) };

    let input_pass = c_password.to_str().unwrap();
    let input_conf = c_conf.to_str().unwrap();
    let minimum_confirmations: u64 = minimum_confirmations.to_str().unwrap().to_string().parse().unwrap();

    let wallet = open_wallet(input_conf, input_pass).unwrap();

    let txs = txs_get(
        &wallet,
        minimum_confirmations,
        true
    ).unwrap();

    let s = CString::new(txs).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
}

#[no_mangle]
pub unsafe extern "C" fn rust_tx_cancel(
    config: *const c_char,
    password: *const c_char,
    tx_id: *const c_char,
) -> *const c_char {

    init_logger();
    let config = unsafe { CStr::from_ptr(config) };
    let password = unsafe { CStr::from_ptr(password) };
    let tx_id = unsafe { CStr::from_ptr(tx_id) };

    let config = config.to_str().unwrap();
    let password = password.to_str().unwrap();
    let tx_id: u32 = tx_id.to_str().unwrap().to_string().parse().unwrap();
    let wallet = open_wallet(config, password).unwrap();

    match  tx_cancel(&wallet, tx_id) {
        Ok(cancel) => {
            debug!("{}", "Cancel success");
            let s = CString::new(cancel).unwrap();
            let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
            std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
            p
        },Err(e) => {
            debug!("Cancel error {}", e.to_string());
            panic!("{}", e.to_string())
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn rust_tx_receive(
    config: *const c_char,
    password: *const c_char,
    slate: *const c_char,
) -> *const c_char {
    init_logger();
    let config = unsafe { CStr::from_ptr(config) };
    let password = unsafe { CStr::from_ptr(password) };
    let slate = unsafe { CStr::from_ptr(slate) };

    let config = config.to_str().unwrap();
    let password = password.to_str().unwrap();
    let slate = slate.to_str().unwrap();

    let wallet = open_wallet(config, password).unwrap();
    //Send funds to default account for now
    let owner_api = Owner::new(wallet.clone());
    let accounts = owner_api.accounts(None).unwrap();
    let account = &accounts[0].label;

    let receive_slate = tx_receive(&wallet, &account, &slate).unwrap();

    debug!("{}", receive_slate.clone());

    let s = CString::new(receive_slate).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
}

/*
    Get wallet info
    This contains wallet balances
*/
pub fn get_wallet_info(wallet: &Wallet, refresh_from_node: bool, min_confirmations: u64) -> Result<WalletInfo, Error> {
    let api = Owner::new(wallet.clone());
    let (_, wallet_summary) =
        api.retrieve_summary_info(None, refresh_from_node, min_confirmations).unwrap();
    Ok(wallet_summary)
}

/*
    Recover wallet from mnemonic
*/
pub fn recover_from_mnemonic(mnemonic: &str, password: &str, config: &Config, name: &str) -> Result<(), Error> {
    let wallet = get_wallet(&config)?;
    let mut w_lock = wallet.lock();
    let lc = w_lock.lc_provider()?;

    //First check if wallet seed directory exists, if not create
    if let Ok(exists_wallet_seed) = lc.wallet_exists(None) {
        if (exists_wallet_seed) {
            lc.recover_from_mnemonic(ZeroingString::from(mnemonic), ZeroingString::from(password))?;
        } else {
            lc.create_wallet(
                Some(&name),
                Some(ZeroingString::from(mnemonic)),
                32,
                ZeroingString::from(password),
                false,
            )?
        }
    }
    Ok(())
}


/*
    Create a new wallet seed
*/
pub fn mnemonic() -> Result<String, stack_test_epic_keychain::mnemonic::Error> {
    let seed = create_seed(32);
    Ok(mnemonic::from_entropy(&seed).unwrap())
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
    let wallet = inst_wallet::<
        DefaultLCProvider<HTTPNodeClient, ExtKeychain>,
        HTTPNodeClient,
        ExtKeychain,
    >(wallet_config.clone(), node_client)?;
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
    let lc = wallet.lc_provider().unwrap();
    lc.set_top_level_directory(&config.data_file_dir)?;
    Ok(Arc::new(Mutex::new(wallet)))
}

/*
    Get wallet recovery phrase
*/
pub fn wallet_phrase(password: &str, config: Config) -> Result<String, Error> {
    let wallet = get_wallet(&config).unwrap();
    let owner = Owner::new(wallet.clone());
    let mnemonic = owner.get_mnemonic(None, ZeroingString::from(password)).unwrap();
    Ok(format!("{}", &*mnemonic))
}



/*
    Get wallet pmmr range,
    used as start_height and end_height for wallet_scan_outputs
*/
pub fn wallet_pmmr_range(wallet: &Wallet) -> Result<(u64, u64), Error> {
    wallet_lock!(wallet, w);
    let pmmr_range = w.w2n_client().height_range_to_pmmr_indices(0, None)?;
    Ok(pmmr_range)
}


/*

*/
pub fn wallet_scan_outputs(
    wallet: &Wallet,
    start_height: Option<u64>,
) -> Result<String, Error> {

    let tip = {
        wallet_lock!(wallet, w);
        w.w2n_client().get_chain_tip().unwrap()
    };
    println!("{}", tip.0);

    let start_height: u64 = match start_height {
        Some(h) => h,
        None => 1,
    };

    let info = scan(
        wallet.clone(),
        None,
        false,
        start_height,
        tip.0,
        &None
    ).unwrap();

    let result = info.last_pmmr_index;
    println!("{:?}", info);

    let parent_key_id = {
        wallet_lock!(wallet, w);
        w.parent_key_id().clone()
    };

    wallet_lock!(wallet, w);
    let mut batch = w.batch(None)?;
    batch.save_last_confirmed_height(&parent_key_id, info.height)?;
    batch.commit()?;


    Ok(serde_json::to_string(&result).unwrap())
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
    amount: u64,
    minimum_confirmations: u64,
) -> Result<String, Error> {

    let mut result = vec![];
    wallet_lock!(wallet, w);

    for selection_strategy_is_use_all in vec![true, false].into_iter() {
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

        if let Ok(slate) = owner::init_send_tx(&mut **w, None, args, true) {
            result.push(Strategy {
                selection_strategy_is_use_all,
                total: slate.amount,
                fee: slate.fee,

            })
        }
    }
    Ok(serde_json::to_string(&result).unwrap())
}

fn update_state<'a, L, C, K>(
    wallet_inst: Arc<Mutex<Box<dyn WalletInst<'a, L, C, K>>>>,
) -> Result<bool, Error>
    where
        L: WalletLCProvider<'a, C, K>,
        C: NodeClient + 'a,
        K: Keychain + 'a,
{
    let parent_key_id = {
        wallet_lock!(wallet_inst, w);
        w.parent_key_id().clone()
    };
    let mut client = {
        wallet_lock!(wallet_inst, w);
        w.w2n_client().clone()
    };
    let tip = client.get_chain_tip()?;

    // Step 1: Update outputs and transactions purely based on UTXO state

    {
        if !match owner::update_wallet_state(wallet_inst.clone(), None, &None, true) {
            Ok(_) => true,
            Err(_) => false,
        } {
            // We are unable to contact the node
            return Ok(false);
        }
    }

    let mut txs = {
        owner::retrieve_txs(wallet_inst.clone(), None, &None, true, None, None).unwrap()
    };

    for tx in txs.1.iter_mut() {
        // Step 2: Cancel any transactions with an expired TTL
        if let Some(e) = tx.ttl_cutoff_height {
            if tip.0 >= e {
                owner::cancel_tx(wallet_inst.clone(), None, &None, Some(tx.id), None).unwrap();
                continue;
            }
        }
        // Step 3: Update outstanding transactions with no change outputs by kernel
        if tx.confirmed {
            continue;
        }
        if tx.amount_debited != 0 && tx.amount_credited != 0 {
            continue;
        }
        if let Some(e) = tx.kernel_excess {
            let res = client.get_kernel(&e, tx.kernel_lookup_min_height, Some(tip.0));
            let kernel = match res {
                Ok(k) => k,
                Err(_) => return Ok(false),
            };
            if let Some(k) = kernel {
                debug!("Kernel Retrieved: {:?}", k);
                wallet_lock!(wallet_inst, w);
                let mut batch = w.batch(None)?;
                tx.confirmed = true;
                tx.update_confirmation_ts();
                batch.save_tx_log_entry(tx.clone(), &parent_key_id)?;
                batch.commit()?;
            }
        }
    }

    return Ok(true);
}

pub fn txs_get(
    wallet: &Wallet,
    minimum_confirmations: u64,
    refresh_from_node: bool,
) -> Result<String, Error> {

    let api = Owner::new(wallet.clone());
    let txs = api.retrieve_txs(None, true, None, None)?;
    let result = (txs.1);

    debug!("{}", serde_json::to_string(&result.clone()).unwrap());

    Ok(serde_json::to_string(&result).unwrap())
}

/*
    Init tx as sender
*/
pub fn tx_create(
    wallet: &Wallet,
    amount: u64,
    minimum_confirmations: u64,
    selection_strategy_is_use_all: bool,
) -> Result<String, Error> {
    let owner_api = Owner::new(wallet.clone());
    let accounts = owner_api.accounts(None).unwrap();
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

    let result = owner_api.init_send_tx(None, args);
    match result {
        Ok(slate)=> {
            //TODO - Send Slate
            //Lock slate uptputs
            owner_api.tx_lock_outputs(None, &slate, 0);
            Ok(serde_json::to_string(&slate).map_err(|e| ErrorKind::GenericError(e.to_string()))?)
        },
        Err(e)=> {
            Ok(serde_json::to_string(&e.to_string()).map_err(|e| ErrorKind::GenericError(e.to_string()))?)
        }
    }
}

/*
    Cancel tx by id
*/
pub fn tx_cancel(wallet: &Wallet, id: u32) -> Result<String, Error> {
    let api = Owner::new(wallet.clone());
    api.cancel_tx(None, Some(id), None);
    Ok("".to_owned())
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

pub fn tx_receive(wallet: &Wallet, account: &str, str_slate: &str) -> Result<String, Error> {
    let slate = Slate::deserialize_upgrade(str_slate).unwrap();
    let foreign_api = Foreign::new(wallet.clone(), None, Some(check_middleware));
    let response = foreign_api.receive_tx(&slate, Some(&account), None).unwrap();
    Ok(serde_json::to_string(&response).map_err(|e| ErrorKind::GenericError(e.to_string()))?)
}

/*

*/
pub fn tx_finalize(wallet: &Wallet, str_slate: &str) -> Result<String, Error> {
    let slate = Slate::deserialize_upgrade(str_slate).unwrap();
    let owner_api = Owner::new(wallet.clone());
    let final_slate = owner_api.finalize_tx(None, &slate).unwrap();
    Ok(serde_json::to_string(&final_slate).map_err(|e| ErrorKind::GenericError(e.to_string()))?)
}

/*
    Return secret key and public key as strings
*/
pub fn private_pub_key_pair() -> Result<(PublicKey, SecretKey), Error> {
    let s = Secp256k1::new();
    let secret_key = SecretKey::new(&s, &mut thread_rng());
    let public_key = PublicKey::from_secret_key(&s, &secret_key).unwrap();
    Ok((public_key, secret_key))
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

pub fn build_post_slate_request(receiver_address: &str, sender_secret_key: &str, tx: String) -> String {
    let secret_key: SecretKey = serde_json::from_str(sender_secret_key).unwrap();
    let s = Secp256k1::new();
    let pub_key = PublicKey::from_secret_key(&s, &secret_key).unwrap();
    let address_sender = get_epicbox_address(pub_key, EPIC_BOX_ADDRESS.clone(), Some(EPIC_BOX_PORT));

    let address_receiver = EpicboxAddress::from_str(receiver_address).unwrap();
    let pub_key_receiver = address_receiver.public_key().unwrap();
    let address_receiver = get_epicbox_address(pub_key_receiver, EPIC_BOX_ADDRESS.clone(), Some(EPIC_BOX_PORT));

    let mut challenge = String::new();
    let message = EpicboxMessage::new(
        tx, &address_receiver.clone(), &address_receiver.public_key().unwrap(), &secret_key
    ).map_err(|_| WsError::new(WsErrorKind::Protocol, "could not encrypt slate!")).unwrap();
    let message_ser = serde_json::to_string(&message).unwrap();

    let to_address = format!("{}@{}", address_receiver.public_key, address_receiver.domain);
    challenge.push_str(&message_ser);
    let signature = sign_challenge(&challenge, &secret_key).unwrap().to_hex();
    let json_request = format!(r#"{{"type": "PostSlate", "from": "{}", "to": "{}", "str": {}, "signature": "{}"}}"#,
        address_sender,
        to_address,
        json::as_json(&message_ser),
        signature);

    json_request

}

pub fn connect_to_ws() -> WebSocket<AutoStream> {
    let url = format!("ws://{}:{}", EPIC_BOX_ADDRESS, EPIC_BOX_PORT);
    let (socket, response) = connect(
        Url::parse(&url).unwrap()
    ).expect("Can't connect");
    socket
}

/*

*/
pub fn open_wallet(config_json: &str, password: &str) -> Result<Wallet, Error> {
    let config = Config::from_str(config_json).unwrap();
    let wallet = get_wallet(&config)?;

    let mut opened = false;
    {
        let mut wallet_lock = wallet.lock();
        let lc = wallet_lock.lc_provider()?;
        if let Ok(exists_wallet) = lc.wallet_exists(None) {
            if exists_wallet {
                lc.open_wallet(None, ZeroingString::from(password), false, false).unwrap();
                let wallet_inst = lc.wallet_inst()?;
                if let Some(account) = config.account {
                    wallet_inst.set_parent_key_id_by_name(&account)?;
                    opened = true;
                }
            }
        }
    }
    debug!("Opened is {}", opened);
    if opened {
        Ok(wallet)
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



//Coingecko and binance integration
#[derive(Debug, Serialize, Deserialize)]
struct Coin {
    id: String,
    symbol: String,
    name: String
}
#[derive(Debug, Serialize, Deserialize)]
struct Ticker {
    base: String,
    target: String,
    last: f64
}
#[derive(Debug, Serialize, Deserialize)]
struct CoinTicker {
    name: String,
    tickers: Vec<Ticker>
}

#[derive(Debug, Serialize, Deserialize)]
struct Price {
    bitcoin: HashMap<String, i32>
}

pub fn fiat_price(symbol: &str, base_currency: &str) -> f64 {

    let symbol = symbol.to_lowercase();
    let base_currency = base_currency.to_lowercase();

    let url = "https://api.coingecko.com/api/v3/coins/list";
    let resp = reqwest::blocking::get(url).unwrap();
    let coins = resp.json::<Vec<Coin>>().unwrap();
    let mut coin_id = "".to_string();

    for coin in coins {
        if coin.symbol == symbol {
            coin_id = coin.id;
        }
    }

    let mut epic_btc_price = 0.0;
    let ticker_url = format!("https://api.coingecko.com/api/v3/coins/{}/tickers", coin_id);
    let epic_btc_ticker = reqwest::blocking::get(ticker_url).unwrap();
    let body = epic_btc_ticker.json::<CoinTicker>().unwrap();

    for ticker in body.tickers {
        if ticker.target == "BTC" {
            epic_btc_price = ticker.last;
        }
    }

    //Get BTC to base currency
    let mut btc_to_base = 0;
    let price_url = format!("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies={}", base_currency);
    let price_req = reqwest::blocking::get(price_url).unwrap();
    let price_resp = price_req.json::<Price>().unwrap();
    btc_to_base = *price_resp.bitcoin.get(&base_currency).unwrap();
    let mut final_price = 0.00;
    if epic_btc_price != 0.00 && btc_to_base != 0 {
        final_price = epic_btc_price * f64::from(btc_to_base);
    }
    final_price

}

//To be deleted
pub fn get_default_config() -> Config {
    ///data/user/0/com.example.flutter_libepiccash_example/app_flutter/test/
    Config {
        wallet_dir: String::from("default"),
        check_node_api_http_addr: String::from("http://95.216.215.107:3413"),
        chain: String::from("mainnet"),
        account: Some(String::from("default")),
        api_listen_port: 3413,
        api_listen_interface: "95.216.215.107".to_string()
    }
}




#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        let result = 2 + 2;
        assert_eq!(result, 4);
    }
}
