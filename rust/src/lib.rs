use std::os::raw::{c_char};
use std::ffi::{CString, CStr};
use std::collections::HashMap;
use std::sync::Arc;
use std::path::{Path, PathBuf};
use rand::thread_rng;
use serde::{Deserialize, Serialize};
use rustc_serialize::json;
use serde_json::to_string;

use stack_test_epic_wallet_api::Owner;
use stack_test_epic_wallet_config::{WalletConfig};
use stack_test_epic_wallet_libwallet::api_impl::types::InitTxArgs;
use stack_test_epic_wallet_libwallet::api_impl::owner;
use stack_test_epic_wallet_impls::{
    DefaultLCProvider, DefaultWalletImpl, HTTPNodeClient, HttpSlateSender, SlateSender,
};

use stack_test_epic_keychain::mnemonic;
use stack_test_epic_core::global::ChainTypes;
use stack_test_epic_core::global;
use stack_test_epic_util::file::get_first_line;
use stack_test_epic_util::ZeroingString;
use stack_test_epic_util::Mutex;
use stack_test_epic_wallet_libwallet::{
    Error, ErrorKind, WalletInst, WalletLCProvider, NodeClient, WalletInfo, wallet_lock, scan
};
use stack_test_epic_util::secp::{SecretKey, PublicKey, Secp256k1};
use stack_test_epic_keychain::{Keychain, ExtKeychain};
use stack_test_epic_util::secp::rand::Rng;

//
// use epicboxlib::types::{EpicboxAddress, EpicboxError, version_bytes};

#[derive(Serialize, Deserialize, Clone, RustcEncodable)]
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

#[no_mangle]
pub unsafe extern "C" fn string_from_rust(ptr: *const c_char) -> *const c_char {

    android_logger::init_once(
        AndroidConfig::default().with_min_level(Level::Trace),
    );

    debug!("THis is a debug {}", "message");

    let password = stack_test_epic_util::ZeroingString::from("58498542".to_string());
    let config = get_default_config();
    let phrase = mnemonic().unwrap();
    // let password = "58498542".to_string();
    //
    let wallet = get_wallet(&config).unwrap();
    let mut wallet_lock = wallet.lock();
    let lc = wallet_lock.lc_provider().unwrap();
    let rec_phrase = stack_test_epic_util::ZeroingString::from(phrase.clone());
    let name = "TestWallet".to_string();

    // Get wallet directory
    let wallet_directory = lc.get_top_level_directory().unwrap();
    let relative_path = PathBuf::from(wallet_directory.clone());
    let mut absolute_path = std::env::current_dir().unwrap();
    absolute_path.push(relative_path);

    debug!("Absolute path is {:?}", absolute_path);
    debug!("Wallet directory is {}", wallet_directory);


    let config_json = json::encode(&config).unwrap();

    // lc.create_wallet(
    //     Some(&name),
    //     Some(rec_phrase),
    //     32,
    //     password.clone(),
    //     false,
    // ).unwrap();

    //Recover wallet

    // let wallet_exists = lc.wallet_exists(Some(&name)).unwrap();
    // debug!("Wallet exists is {}", wallet_exists);
    //
    // let mnem = "purpose traffic uniform step moon bench amazing brand evil lobster notice rookie crush fault obvious luggage decade when inch imitate crumble lady material raw".to_string();
    // let pass_me = "58498542".to_string();
    // let rec = recover_from_mnemonic(&mnem, &pass_me, &config).unwrap();
    // debug!("Wallet rec response {}", rec);



    // let wallet = open_wallet(&config_json, &password).unwrap();
    // let test_me = lc.get_mnemonic(Some(&name), password).unwrap();
    // let this_mnemonic = format!("{}", &*test_me);
    // debug!("Mnemonic for existing wallet is {}", this_mnemonic);
    //
    //
    // //Open wallet and get balance
    // let str_pass = "58498542".to_string();
    // let wallet = open_wallet(&config_json, &str_pass).unwrap();
    // let info = get_wallet_info(&wallet, true, 10);
    // debug!("Wallet info is {:?}", info);
    // let my_pass = "58498542".to_string();
    // let conf = get_default_config();
    // let recovery = wallet_phrase(&password, config).unwrap();

    // open_wallet(config_json: &str, password: &str)


    // let config = Config::from_str(config_json).unwrap();

    // let node_url = "127.0.0.1".to_string();
    // let node_client = HTTPNodeClient::new(&node_url, None);
    // let wallet_config = create_wallet_config(config);

    // let ss = Secp256k1::new();
    // let secret_key = SecretKey::new(&ss, &mut thread_rng());
    // let public_key = PublicKey::from_secret_key(&ss, &secret_key).unwrap();


    // let to_return = format!("{}", &*mnemonic);
    let s = CString::new(name).unwrap();
    let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
    std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
    p
}

// #[no_mangle]
// pub unsafe extern "C" fn string_from_rusts(ptr: *const c_char) -> *const c_char {
//     let phrase = "Likho".to_string();
//
//     let s = CString::new(phrase).unwrap();
//     let p = s.as_ptr(); // Get a pointer to the underlaying memory for s
//     std::mem::forget(s); // Give up the responsibility of cleaning up/freeing s
//     ptr
// }

// #[no_mangle]
// pub extern fn get_mnemonic() -> *const *const u8 {
//
//     let mnemonic = mnemonic().unwrap();
//     let mut split = mnemonic.split(" ");
//
//     let mut vec = Vec::new();
//     for s in split {
//         vec.push(s.as_ptr());
//         // println!("{}", s)
//     }
//
//     let p = vec.as_ptr();
//     std::mem::forget(vec);
//     p
// }

// #[no_mangle]
// pub extern fn get_fiat_price() -> *const c_char {
//     let seed = CString::new(mnemonic().unwrap()).unwrap();
//     let p = seed.as_ptr(); // Get a pointer to the underlaying memory for s
//     std::mem::forget(seed); // Give up the responsibility of cleaning up/freeing s
//     p
// }

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
    Create a new wallet
*/
pub fn wallet_init() -> Result<String, Error> {

    let config = get_default_config();
    let phrase = mnemonic().unwrap();
    let password = "58498542".to_string();

    // let config = Config::from_str(config_json).unwrap();
    let wallet = get_wallet(&config)?;
    let mut wallet_lock = wallet.lock();
    let lc = wallet_lock.lc_provider()?;
    lc.create_wallet(
        None,
        Some(ZeroingString::from(phrase)),
        32,
        ZeroingString::from(password),
        false,
    )?;

    Ok("Wallet created".to_owned())
}
//
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
    Recover wallet from mnemonic
*/
pub fn recover_from_mnemonic(mnemonic: &str, password: &str, config: &Config) -> Result<String, Error> {
    let wallet = get_wallet(&config)?;
    let mut w_lock = wallet.lock();
    let lc = w_lock.lc_provider()?;

    lc.recover_from_mnemonic(ZeroingString::from(mnemonic), ZeroingString::from(password)).unwrap();
    Ok("Wallet has been recovered".to_owned())
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
    last_retrieved_index: u64,
    highest_index: u64,
) -> Result<String, Error> {
    let info = scan(
        wallet.clone(),
        None,
        false,
        last_retrieved_index,
        highest_index,
        &None,
    )?;

    debug!("Debugging scan {:?}", info);
    Ok("Likho".to_owned())
    // let result = info.last_pmmr_index;
    //
    // let parent_key_id = {
    //     wallet_lock!(wallet, w);
    //     w.parent_key_id().clone()
    // };
    // {
    //     wallet_lock!(wallet, w);
    //     let mut batch = w.batch(None)?;
    //     batch.save_last_confirmed_height(&parent_key_id, info.height)?;
    //     batch.commit()?;
    // };
    //
    // Ok(serde_json::to_string(&result).unwrap())
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

// #[derive(Serialize, Deserialize)]
// struct Strategy {
//     selection_strategy_is_use_all: bool,
//     total: u64,
//     fee: u64,
// }
//
// /*
//     Get transaction fees
//     all possible Coin/Output selection strategies.
// */
// pub fn tx_strategies(
//     wallet: &Wallet,
//     amount: u64,
//     minimum_confirmations: u64,
// ) -> Result<String, Error> {
//
//     let mut result = vec![];
//     wallet_lock!(wallet, w);
//
//     for selection_strategy_is_use_all in vec![true, false].into_iter() {
//         let args = InitTxArgs {
//             src_acct_name: None,
//             amount,
//             minimum_confirmations,
//             max_outputs: 500,
//             num_change_outputs: 1,
//             estimate_only: Some(true),
//             message: None,
//             ..Default::default()
//         };
//
//         if let Ok(slate) = owner::init_send_tx(&mut **w, None, args, true) {
//             result.push(Strategy {
//                 selection_strategy_is_use_all,
//                 total: slate.amount,
//                 fee: slate.fee,
//
//             })
//         }
//     }
//     Ok(serde_json::to_string(&result).unwrap())
// }
//
// pub fn private_pub_key_pair() -> Result<(SecretKey, PublicKey), Error> {
//     let s = Secp256k1::new();
//     let secret_key = SecretKey::new(&s, &mut thread_rng());
//     let public_key = PublicKey::from_secret_key(&s, &secret_key).unwrap();
//     Ok((secret_key, public_key))
//
// }
//
// pub fn get_epicbox_address(
//     public_key: PublicKey,
//     domain: Option<String>,
//     port: Option<u16>) -> String {
//     EpicboxAddress::new(public_key, domain, port).to_string()
// }
//
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
    println!("Opened is {}", opened);
    if opened {
        Ok(wallet)
    } else {
        Err(Error::from(ErrorKind::WalletSeedDoesntExist))
    }
}
//
//
// pub fn close_wallet(wallet: &Wallet) -> Result<String, Error> {
//     let mut wallet_lock = wallet.lock();
//     let lc = wallet_lock.lc_provider()?;
//     if let Ok(open_wallet) = lc.wallet_exists(None) {
//         if open_wallet {
//             lc.close_wallet(None)?;
//         }
//     }
//     Ok("Wallet has been closed".to_owned())
// }
//

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

pub fn fiat_price(symbol: String, base_currency: String) -> f64 {

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

pub fn get_default_config() -> Config {
    ///data/user/0/com.example.epic_cash_wallet/app_flutter/test/
    Config {
        wallet_dir: String::from("default"),
        check_node_api_http_addr: String::from("http://127.0.0.1:3413"),
        chain: String::from("mainnet"),
        account: Some(String::from("default")),
        api_listen_port: 3415,
        api_listen_interface: "127.0.0.1".to_string()
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
