use stack_epic_wallet_libwallet::Error;
use stack_epic_wallet_controller::Error as EpicWalletControllerError;

use crate::ffi::get_mnemonic;
use crate::ffi::wallet_init;
use crate::ffi::rust_open_wallet;
use crate::ffi::rust_wallet_balances;
use crate::ffi::rust_wallet_scan_outputs;
use crate::ffi::rust_create_tx;
use crate::ffi::rust_txs_get;
use crate::ffi::rust_tx_cancel;
use crate::ffi::rust_get_chain_height;
use crate::ffi::rust_epicbox_listener_start;
use crate::ffi::_listener_cancel;
use crate::ffi::rust_validate_address;
use crate::ffi::rust_get_wallet_address;
use crate::ffi::rust_get_tx_fees;
use crate::ffi::rust_delete_wallet;

use android_logger::FilterBuilder;
pub mod config;
pub mod mnemonic;
pub mod wallet;
pub mod listener;

#[macro_export]
macro_rules! ensure_wallet (
    ($wallet_ptr:expr, $wallet:ident) => (
        if ($wallet_ptr as *mut Wallet).as_mut().is_none() {
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

#[macro_use] extern crate log;
extern crate android_logger;
extern crate simplelog;

use log::Level;
use android_logger::Config as AndroidConfig;

pub mod ffi;

#[cfg(test)]
mod test_vectors {
    use super::*;
    use std::ffi::{CStr, CString};
    use std::os::raw::c_char;
    use std::fs;
    use std::path::PathBuf;
    use std::panic;

    /// Helper to convert a Rust string to a *const c_char
    unsafe fn str_to_cchar_ptr(s: &str) -> *const c_char {
        let cstring = CString::new(s).expect("CString::new failed");
        let ptr = cstring.as_ptr();
        // We deliberately `forget` here because we're passing it into FFI.
        std::mem::forget(cstring);
        ptr
    }

    /// A basic test that demonstrates creating a wallet & fetching balances WITHOUT a node refresh
    /// (refresh=0), which is causing issues such that testing it properly hasn't been achieved yet.
    #[test]
    fn test_create_and_check_balances_no_refresh() {
        println!("--- BEGIN test_create_and_check_balances_no_refresh ---");

        // 1. Setup config
        let test_dir = PathBuf::from("test_wallet_dir_no_refresh");
        let _ = fs::create_dir_all(&test_dir);

        let config_json = serde_json::json!({
            "wallet_dir": test_dir.to_str().unwrap(),
            "check_node_api_http_addr": "http://epiccash.stackwallet.com:3413",
            "chain": "floonet",
            "account": "default",
            "api_listen_port": 3415,
            "api_listen_interface": "epiccash.stackwallet.com",
        })
            .to_string();

        println!("Config JSON for no-refresh test:\n{config_json}");

        // 2. Convert config & basic FFI pointers.
        let config_ptr = unsafe { str_to_cchar_ptr(&config_json) };
        let password_ptr = unsafe { str_to_cchar_ptr("password123") };
        let wallet_name_ptr = unsafe { str_to_cchar_ptr("no_refresh_wallet") };

        // 3. Generate a new mnemonic.
        let c_mnemonic_ptr = unsafe { get_mnemonic() };
        let c_mnemonic_str = unsafe { CStr::from_ptr(c_mnemonic_ptr) }
            .to_str()
            .expect("Invalid mnemonic UTF-8");
        println!("(no-refresh) Generated Mnemonic: {c_mnemonic_str}");

        // 4. Create a new wallet.
        let mnemonic_ptr = unsafe { str_to_cchar_ptr(c_mnemonic_str) };
        let creation_result_ptr = unsafe {
            wallet_init(config_ptr, mnemonic_ptr, password_ptr, wallet_name_ptr)
        };
        let creation_result_str = unsafe {
            CStr::from_ptr(creation_result_ptr).to_string_lossy().into_owned()
        };
        if creation_result_str.is_empty() {
            println!("(no-refresh) Wallet created successfully.");
        } else {
            println!("(no-refresh) Wallet creation error: {creation_result_str}");
        }

        // 5. Open the wallet.
        let open_result_ptr = unsafe { rust_open_wallet(config_ptr, password_ptr) };
        let open_result_str = unsafe {
            CStr::from_ptr(open_result_ptr).to_string_lossy().into_owned()
        };
        println!("(no-refresh) Result from opening wallet: {open_result_str}");

        // 6. Check wallet balances with refresh=0.
        let wallet_ptr_cstr = open_result_str.clone();
        let refresh_str_ptr = unsafe { str_to_cchar_ptr("0") }; // No refresh.
        let min_confirmations_str_ptr = unsafe { str_to_cchar_ptr("10") };

        let balances_ptr = unsafe {
            rust_wallet_balances(
                unsafe { str_to_cchar_ptr(&wallet_ptr_cstr) },
                refresh_str_ptr,
                min_confirmations_str_ptr,
            )
        };
        let balances_str = unsafe {
            CStr::from_ptr(balances_ptr).to_string_lossy().into_owned()
        };
        println!("(no-refresh) Wallet Balances: {balances_str}");

        // 7. Clean up: delete the wallet directory.
        let delete_ptr = unsafe {
            rust_delete_wallet(
                unsafe { str_to_cchar_ptr(&wallet_ptr_cstr) },
                config_ptr,
            )
        };
        let delete_str = unsafe {
            CStr::from_ptr(delete_ptr).to_string_lossy().into_owned()
        };
        println!("(no-refresh) Delete wallet result: {delete_str}");

        // Remove the ephemeral wallet directory.
        let _ = fs::remove_dir_all(&test_dir);

        println!("--- END test_create_and_check_balances_no_refresh ---");
    }

    /// A basic test that demonstrates creating a wallet & fetching balances WITH a node refresh
    fn test_wallet_init_and_open_minimal() {
        use std::fs;
        use std::path::PathBuf;
        use std::ffi::{CString, CStr};
        use std::os::raw::c_char;

        println!("--- BEGIN test_wallet_init_and_open_minimal ---");

        // 1. Setup wallet config.
        let test_dir = PathBuf::from("test_wallet_init_open_minimal");
        let _ = fs::create_dir_all(&test_dir);

        let config_json = serde_json::json!({
        "wallet_dir": test_dir.to_str().unwrap(),
        "check_node_api_http_addr": "http://epiccash.stackwallet.com:3413",
        "chain": "floonet",
        "account": "default",
        "api_listen_port": 3415,
        "api_listen_interface": "127.0.0.1",
    })
            .to_string();

        // Helper to create a *const c_char from &str.
        unsafe fn c_ptr(s: &str) -> *const c_char {
            let cstring = CString::new(s).expect("CString::new failed");
            let ptr = cstring.as_ptr();
            std::mem::forget(cstring);
            ptr
        }

        let config_ptr = unsafe { c_ptr(&config_json) };
        let password_ptr = unsafe { c_ptr("testpassword") };
        let name_ptr = unsafe { c_ptr("init_open_wallet") };

        // 2. Generate new mnemonic.
        let mnemonic_ptr = unsafe { get_mnemonic() };
        let mnemonic_str = unsafe { CStr::from_ptr(mnemonic_ptr).to_string_lossy().into_owned() };
        println!("(init_open_minimal) Generated mnemonic: {mnemonic_str}");

        // 3. Create (init) the wallet with that mnemonic.
        let creation_res_ptr = unsafe {
            wallet_init(config_ptr, c_ptr(&mnemonic_str), password_ptr, name_ptr)
        };
        let creation_res_str = unsafe {
            CStr::from_ptr(creation_res_ptr).to_string_lossy().into_owned()
        };
        if creation_res_str.is_empty() {
            println!("(init_open_minimal) Wallet created successfully.");
        } else {
            println!("(init_open_minimal) Wallet creation error: {creation_res_str}");
        }

        // 4. Open the wallet.
        let open_res_ptr = unsafe {
            rust_open_wallet(config_ptr, password_ptr)
        };
        let open_res_str = unsafe {
            CStr::from_ptr(open_res_ptr).to_string_lossy().into_owned()
        };
        println!("(init_open_minimal) rust_open_wallet returned: {open_res_str}");

        // 5. Clean up wallet data
        let _ = fs::remove_dir_all(&test_dir);

        println!("--- END test_wallet_init_and_open_minimal ---");
    }

    #[test]
    fn test_wallet_balances_no_refresh() {
        use std::fs;
        use std::path::PathBuf;
        use std::ffi::{CString, CStr};
        use std::os::raw::c_char;

        println!("--- BEGIN test_wallet_balances_no_refresh ---");

        let test_dir = PathBuf::from("test_wallet_balances_no_refresh");
        let _ = fs::create_dir_all(&test_dir);

        let config_json = serde_json::json!({
        "wallet_dir": test_dir.to_str().unwrap(),
        "check_node_api_http_addr": "http://epiccash.stackwallet.com:3413",
        "chain": "floonet",
        "account": "default",
        "api_listen_port": 3415,
        "api_listen_interface": "127.0.0.1",
    })
            .to_string();

        unsafe fn c_ptr(s: &str) -> *const c_char {
            let cstring = CString::new(s).expect("CString::new failed");
            let ptr = cstring.as_ptr();
            std::mem::forget(cstring);
            ptr
        }

        let config_ptr = unsafe { c_ptr(&config_json) };
        let password_ptr = unsafe { c_ptr("testpassword") };

        // 1. Create and open the wallet.
        let mnemonic_ptr = unsafe { get_mnemonic() };
        let mnemonic_str = unsafe { CStr::from_ptr(mnemonic_ptr).to_string_lossy().into_owned() };
        println!("(balances_no_refresh) Generated mnemonic: {mnemonic_str}");

        let creation_res_ptr = unsafe {
            wallet_init(config_ptr, c_ptr(&mnemonic_str), password_ptr, c_ptr("test_balances_wallet"))
        };
        let creation_res_str = unsafe {
            CStr::from_ptr(creation_res_ptr).to_string_lossy().into_owned()
        };
        println!("(balances_no_refresh) wallet_init result: {creation_res_str}");

        let open_res_ptr = unsafe { rust_open_wallet(config_ptr, password_ptr) };
        let open_res_str = unsafe { CStr::from_ptr(open_res_ptr).to_string_lossy().into_owned() };
        println!("(balances_no_refresh) rust_open_wallet: {open_res_str}");

        // 2. Check balances, no refresh.
        let min_conf_ptr = unsafe { c_ptr("10") };
        let refresh_ptr = unsafe { c_ptr("0") }; // "0" => no refresh

        let balances_ptr = unsafe {
            rust_wallet_balances(c_ptr(&open_res_str), refresh_ptr, min_conf_ptr)
        };
        let balances_str = unsafe {
            CStr::from_ptr(balances_ptr).to_string_lossy().into_owned()
        };
        println!("(balances_no_refresh) wallet balances: {balances_str}");

        // 3. Clean up.
        let _ = fs::remove_dir_all(&test_dir);

        println!("--- END test_wallet_balances_no_refresh ---");
    }
}
