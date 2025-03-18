use stack_epic_wallet_libwallet::Error;
use stack_epic_wallet_controller::Error as EpicWalletControllerError;

use crate::ffi::get_mnemonic;
use crate::ffi::wallet_init;
use crate::ffi::rust_open_wallet;
use crate::ffi::rust_wallet_balances;
// use crate::ffi::rust_wallet_scan_outputs;
// use crate::ffi::rust_create_tx;
// use crate::ffi::rust_txs_get;
// use crate::ffi::rust_tx_cancel;
// use crate::ffi::rust_get_chain_height;
// use crate::ffi::rust_epicbox_listener_start;
// use crate::ffi::_listener_cancel;
// use crate::ffi::rust_validate_address;
// use crate::ffi::rust_get_wallet_address;
// use crate::ffi::rust_get_tx_fees;
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
mod tests {
    use super::*;
    use std::ffi::{CStr, CString};
    use std::os::raw::c_char;
    use std::fs;
    use std::path::PathBuf;

    use crate::mnemonic::mnemonic;
    use crate::wallet::validate_address;
    use crate::wallet::get_chain_height;
    use crate::wallet::get_wallet_info;
    use crate::wallet::convert_deci_to_nano;
    use crate::wallet::nano_to_deci;

    /// Helper to convert a Rust string to a *const c_char.
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
                str_to_cchar_ptr(&wallet_ptr_cstr),
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
                str_to_cchar_ptr(&wallet_ptr_cstr),
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
    #[test]
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
        "api_listen_interface": "epiccash.stackwallet.com",
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
        "api_listen_interface": "epiccash.stackwallet.com",
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

    use serde_json::json;

    /// A helper function to convert a Rust string to a *const c_char.
    unsafe fn str_to_cchar(s: &str) -> *const c_char {
        let cstring = CString::new(s).expect("CString::new failed");
        let ptr = cstring.as_ptr();
        std::mem::forget(cstring);
        ptr
    }

    /// A helper function to setup a test directory.
    fn setup_test_dir(name: &str) -> PathBuf {
        let dir = PathBuf::from(format!("test_wallet_dir_{}", name));
        let _ = fs::create_dir_all(&dir);
        dir
    }

    /// A helper function to cleanup a test directory.
    fn cleanup_test_dir(dir: &PathBuf) {
        let _ = fs::remove_dir_all(dir);
    }

    /// A helper function to create a test wallet configuration.
    fn create_test_config(dir: &PathBuf) -> String {
        json!({
            "wallet_dir": dir.to_str().unwrap(),
            "check_node_api_http_addr": "http://epiccash.stackwallet.com:3413",
            "chain": "floonet",
            "account": "default",
            "api_listen_port": 3415,
            "api_listen_interface": "epiccash.stackwallet.com",
        }).to_string()
    }

    /// Test vectors for mnemonic generation.
    #[test]
    fn test_mnemonic_generation_with_vectors() {
        println!("=== Mnemonic Generation Test Vectors ===");

        // Test multiple mnemonic generations.
        for i in 1..=3 {
            match mnemonic() {
                Ok(phrase) => {
                    println!("Test Vector {i}:");
                    println!("Generated Mnemonic: {}", phrase);

                    // Get word count and characteristics.
                    let words: Vec<&str> = phrase.split_whitespace().collect();
                    println!("Word Count: {}", words.len());

                    // Generate entropy from mnemonic.
                    use stack_epic_keychain::mnemonic::to_entropy;
                    match to_entropy(&phrase) {
                        Ok(entropy) => {
                            println!("Entropy (hex): {}", hex::encode(&entropy));
                            println!("Entropy length: {} bytes", entropy.len());
                        },
                        Err(e) => println!("Entropy generation failed: {}", e),
                    }
                    println!("---");
                },
                Err(e) => println!("Failed to generate mnemonic {}: {:?}", i, e),
            }
        }
    }

    /// Test vectors for wallet creation.
    #[test]
    fn test_wallet_creation_vectors() {
        println!("=== Wallet Creation Test Vectors ===");

        let test_dir = setup_test_dir("creation");
        let config_json = create_test_config(&test_dir);

        unsafe {
            // Generate test vectors for wallet creation.
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("test_password");
            let name_ptr = str_to_cchar("test_wallet");

            // Get a mnemonic.
            let mnemonic_ptr = get_mnemonic();
            let mnemonic = CStr::from_ptr(mnemonic_ptr).to_str().unwrap();
            println!("Input Mnemonic: {}", mnemonic);

            // Create wallet.
            let result_ptr = wallet_init(
                config_ptr,
                str_to_cchar(mnemonic),
                password_ptr,
                name_ptr
            );
            let result = CStr::from_ptr(result_ptr).to_str().unwrap();
            println!("Wallet Creation Result: {}", result);

            // Try to open the wallet.
            let open_result_ptr = rust_open_wallet(config_ptr, password_ptr);
            let open_result = CStr::from_ptr(open_result_ptr).to_str().unwrap();
            println!("Wallet Open Result: {}", open_result);
        }

        cleanup_test_dir(&test_dir);
    }

    /// Test vectors for address validation.
    #[test]
    fn test_address_validation_vectors() {
        println!("=== Address Validation Test Vectors ===");

        let test_addresses = [
            "epic1xdp9qkz8tqhlqv4ryy5kv780kzfsxwjvlxjxkhz4vw9r6fz4hc5qzezyzj@epicbox.epic.tech",
            "invalid_address",
            "epic1abc@epicbox.epic.tech",
            "@epicbox.epic.tech",
            "epic1xdp9qkz8tqhlqv4ryy5kv780kzfsxwjvlxjxkhz4vw9r6fz4hc5qzezyzj",
        ];
        // TODO: Figure out why eg.
        // "esXrtQYZzs7DveZV4pxmXr8nntSjEkmxLddCF4hoEjVUh9nQYP7j@epicbox.stackwallet.com" throws.

        for address in &test_addresses {
            println!("Testing address: {}", address);
            let is_valid = validate_address(address);
            println!("Validation result: {}", is_valid);
        }
    }

    /// Test vectors for wallet info retrieval.
    #[test]
    fn test_chain_height_vectors() {
        println!("=== Chain Height Test Vectors ===");

        let test_dir = setup_test_dir("chain_height");
        let config_json = create_test_config(&test_dir);

        match get_chain_height(&config_json) {
            Ok(height) => println!("Chain height: {}", height),
            Err(e) => println!("Error getting chain height: {}", e),
        }

        cleanup_test_dir(&test_dir);
    }

    /// Test vectors for wallet info retrieval.
    #[test]
    fn test_nano_conversion_vectors() {
        println!("=== Nano Conversion Test Vectors ===");

        let test_values = [
            0.00000001,
            1.0,
            123.45678,
            9999.99999999,
            0.123456789,
        ];

        for &value in &test_values {
            println!("Original value (EPIC): {}", value);
            let nano = convert_deci_to_nano(value);
            println!("Converted to nano: {}", nano);
            let back_to_epic = nano_to_deci(nano);
            println!("Converted back to EPIC: {}", back_to_epic);
            println!("---");
        }
    }
}
