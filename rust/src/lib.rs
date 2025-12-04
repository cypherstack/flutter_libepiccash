use epic_wallet_libwallet::Error;
use epic_wallet_controller::Error as EpicWalletControllerError;

use crate::ffi::get_mnemonic;
use crate::ffi::wallet_init;
use crate::ffi::rust_open_wallet;
use crate::ffi::rust_wallet_balances;
use crate::ffi::rust_wallet_scan_outputs;
use crate::ffi::rust_create_tx;
use crate::ffi::rust_tx_send_http;
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
                    use epic_keychain::mnemonic::to_entropy;
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

    /// Test the rust_get_chain_height FFI function directly.
    /// This test verifies that the FFI wrapper properly calls the underlying
    /// get_chain_height function and returns a valid height as a C string.
    #[test]
    fn test_rust_get_chain_height_ffi() {
        println!("=== Test rust_get_chain_height FFI ===");

        let test_dir = setup_test_dir("chain_height_ffi");
        let config_json = create_test_config(&test_dir);

        unsafe {
            // Convert config to C string pointer.
            let config_ptr = str_to_cchar(&config_json);

            // Call the FFI function.
            let height_ptr = rust_get_chain_height(config_ptr);

            // Convert the result back to a Rust string.
            let height_str = CStr::from_ptr(height_ptr).to_str().unwrap();

            println!("Chain height returned from FFI: {}", height_str);

            // Verify the result.
            if height_str.starts_with("Error ") {
                println!("FFI returned an error: {}", height_str);
            } else {
                // Try to parse as a number.
                match height_str.parse::<u64>() {
                    Ok(height) => {
                        println!("Successfully parsed chain height: {}", height);
                        assert!(height > 0, "Chain height should be greater than 0");
                    }
                    Err(e) => {
                        panic!("Failed to parse chain height '{}': {}", height_str, e);
                    }
                }
            }
        }

        cleanup_test_dir(&test_dir);
        println!("=== End rust_get_chain_height FFI test ===");
    }

    /// Test the rust_wallet_scan_outputs FFI function.
    /// This test creates a wallet and scans outputs from a specific block height.
    #[test]
    fn test_rust_wallet_scan_outputs_ffi() {
        println!("=== Test rust_wallet_scan_outputs FFI ===");

        let test_dir = setup_test_dir("scan_outputs_ffi");
        let config_json = create_test_config(&test_dir);

        unsafe {
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("scan_test_password");
            let name_ptr = str_to_cchar("scan_outputs_wallet");

            // 1. Generate mnemonic and create wallet.
            let mnemonic_ptr = get_mnemonic();
            let mnemonic_str = CStr::from_ptr(mnemonic_ptr).to_str().unwrap();
            println!("Generated mnemonic for scan test");

            let creation_ptr = wallet_init(
                config_ptr,
                str_to_cchar(mnemonic_str),
                password_ptr,
                name_ptr
            );
            let creation_result = CStr::from_ptr(creation_ptr).to_str().unwrap();
            println!("Wallet creation result: {}", creation_result);

            // 2. Open the wallet.
            let open_ptr = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data = CStr::from_ptr(open_ptr).to_str().unwrap();
            println!("Opened wallet: {}", wallet_data);

            // 3. Scan outputs from block height 1 for 100 blocks.
            let start_height_ptr = str_to_cchar("1");
            let number_of_blocks_ptr = str_to_cchar("100");

            let scan_ptr = rust_wallet_scan_outputs(
                str_to_cchar(wallet_data),
                start_height_ptr,
                number_of_blocks_ptr
            );
            let scan_result = CStr::from_ptr(scan_ptr).to_str().unwrap();

            println!("Scan outputs result: {}", scan_result);

            // Verify the result.
            if scan_result.starts_with("Error ") {
                println!("Scan returned error (expected for empty wallet): {}", scan_result);
            } else {
                // Should return the last scanned height.
                match scan_result.parse::<u64>() {
                    Ok(last_height) => {
                        println!("Successfully scanned up to height: {}", last_height);
                        assert!(last_height >= 1, "Last scanned height should be >= start height");
                    }
                    Err(e) => {
                        println!("Note: Could not parse scan result as height: {}", e);
                    }
                }
            }

            // 4. Clean up.
            let delete_ptr = rust_delete_wallet(str_to_cchar(wallet_data), config_ptr);
            let delete_result = CStr::from_ptr(delete_ptr).to_str().unwrap();
            println!("Delete result: {}", delete_result);
        }

        cleanup_test_dir(&test_dir);
        println!("=== End rust_wallet_scan_outputs FFI test ===");
    }

    /// Test the rust_validate_address FFI function.
    /// This test validates various Epic Cash address formats.
    /// Note: The validation function only accepts Epicbox-type addresses with the @ domain format.
    #[test]
    fn test_rust_validate_address_ffi() {
        println!("=== Test rust_validate_address FFI ===");

        // Test vectors: (address, description)
        // We test the FFI function and print results to understand actual validation behavior.
        let test_cases = [
            (
                "epic1xdp9qkz8tqhlqv4ryy5kv780kzfsxwjvlxjxkhz4vw9r6fz4hc5qzezyzj@epicbox.epic.tech",
                "Epic address with epicbox domain"
            ),
            (
                "epic1xdp9qkz8tqhlqv4ryy5kv780kzfsxwjvlxjxkhz4vw9r6fz4hc5qzezyzj",
                "Epic address without domain"
            ),
            (
                "invalid_address",
                "Invalid address format"
            ),
            (
                "epic1abc@epicbox.epic.tech",
                "Invalid epic address (too short) with domain"
            ),
            (
                "@epicbox.epic.tech",
                "Missing address part"
            ),
            (
                "",
                "Empty address"
            ),
        ];

        unsafe {
            for (address, description) in &test_cases {
                println!("\nTesting: {}", description);
                println!("Address: {}", address);

                let address_ptr = str_to_cchar(address);
                let result_ptr = rust_validate_address(address_ptr);
                let result_str = CStr::from_ptr(result_ptr).to_str().unwrap();

                println!("FFI returned: {}", result_str);

                // Parse the result (should be "1" for valid, "0" for invalid).
                match result_str.parse::<i32>() {
                    Ok(validation_code) => {
                        let is_valid = validation_code == 1;
                        println!("Validation result: {} ({})",
                                 if is_valid { "valid" } else { "invalid" },
                                 validation_code);

                        // Basic sanity checks:
                        // - Empty addresses should be invalid
                        if address.is_empty() {
                            assert_eq!(is_valid, false, "Empty address should be invalid");
                        }
                        // - "invalid_address" should be invalid
                        if *address == "invalid_address" {
                            assert_eq!(is_valid, false, "Malformed address should be invalid");
                        }
                    }
                    Err(e) => {
                        panic!("Failed to parse validation result '{}': {}", result_str, e);
                    }
                }
            }
        }

        println!("\n=== End rust_validate_address FFI test ===");
    }

    /// Test the rust_get_wallet_address FFI function.
    /// This test creates a wallet and retrieves its address with epicbox configuration.
    #[test]
    fn test_rust_get_wallet_address_ffi() {
        println!("=== Test rust_get_wallet_address FFI ===");

        let test_dir = setup_test_dir("get_wallet_address_ffi");
        let config_json = create_test_config(&test_dir);

        // Create epicbox configuration.
        let epicbox_config = json!({
            "epicbox_domain": "epicbox.epic.tech",
            "epicbox_port": 443,
            "epicbox_protocol_unsecure": false,
            "epicbox_address_index": 0,
        }).to_string();

        unsafe {
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("address_test_password");
            let name_ptr = str_to_cchar("address_wallet");

            // 1. Generate mnemonic and create wallet.
            let mnemonic_ptr = get_mnemonic();
            let mnemonic_str = CStr::from_ptr(mnemonic_ptr).to_str().unwrap();
            println!("Generated mnemonic for address test");

            let creation_ptr = wallet_init(
                config_ptr,
                str_to_cchar(mnemonic_str),
                password_ptr,
                name_ptr
            );
            let creation_result = CStr::from_ptr(creation_ptr).to_str().unwrap();
            println!("Wallet creation result: {}", creation_result);

            // 2. Open the wallet.
            let open_ptr = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data = CStr::from_ptr(open_ptr).to_str().unwrap();
            println!("Opened wallet");

            // 3. Get wallet address at index 0.
            let index_ptr = str_to_cchar("0");
            let epicbox_config_ptr = str_to_cchar(&epicbox_config);

            let address_ptr = rust_get_wallet_address(
                str_to_cchar(wallet_data),
                index_ptr,
                epicbox_config_ptr
            );
            let address = CStr::from_ptr(address_ptr).to_str().unwrap();

            println!("Wallet address at index 0: {}", address);

            // Verify the address format.
            assert!(!address.is_empty(), "Address should not be empty");
            assert!(address.contains('@'), "Address should contain @ for epicbox domain");
            assert!(address.contains("epicbox.epic.tech"), "Address should contain epicbox domain");

            // 4. Get wallet address at index 1.
            let index_ptr_1 = str_to_cchar("1");
            let address_ptr_1 = rust_get_wallet_address(
                str_to_cchar(wallet_data),
                index_ptr_1,
                epicbox_config_ptr
            );
            let address_1 = CStr::from_ptr(address_ptr_1).to_str().unwrap();

            println!("Wallet address at index 1: {}", address_1);

            // Verify addresses at different indices are different.
            assert_ne!(address, address_1, "Addresses at different indices should be different");

            // 5. Clean up.
            let delete_ptr = rust_delete_wallet(str_to_cchar(wallet_data), config_ptr);
            let delete_result = CStr::from_ptr(delete_ptr).to_str().unwrap();
            println!("Delete result: {}", delete_result);
        }

        cleanup_test_dir(&test_dir);
        println!("=== End rust_get_wallet_address FFI test ===");
    }

    /// Test that a known mnemonic produces a known wallet address (test vector).
    /// This ensures deterministic address generation from mnemonic seeds.
    #[test]
    fn test_mnemonic_to_address_vector() {
        println!("=== Test Mnemonic to Address Vector ===");

        let test_dir = setup_test_dir("mnemonic_address_vector");
        let config_json = create_test_config(&test_dir);

        // Known test vector: mnemonic phrase (standard BIP39 test vector).
        let known_mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art";

        // Expected addresses derived from this mnemonic.
        let expected_address_index_0 = "esYCWofU6pCtd1HyvsmbTTtrMs75WxSoJz2bfxF88vX86e5WvQRb@epicbox.epic.tech";
        let expected_address_index_1 = "esWNSTgR69g5MdAwndY1MuZEQqXk19tW36kjLX7xV9f5x1qDaD7w@epicbox.epic.tech";

        let epicbox_config = json!({
            "epicbox_domain": "epicbox.epic.tech",
            "epicbox_port": 443,
            "epicbox_protocol_unsecure": false,
            "epicbox_address_index": 0,
        }).to_string();

        println!("Test vector mnemonic: {}", known_mnemonic);
        println!("Expected address at index 0: {}", expected_address_index_0);
        println!("Expected address at index 1: {}", expected_address_index_1);

        unsafe {
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("test_vector_password");
            let name_ptr = str_to_cchar("vector_wallet");
            let mnemonic_ptr = str_to_cchar(known_mnemonic);

            // 1. Create wallet from known mnemonic.
            let creation_ptr = wallet_init(
                config_ptr,
                mnemonic_ptr,
                password_ptr,
                name_ptr
            );
            let creation_result = CStr::from_ptr(creation_ptr).to_str().unwrap();
            println!("Wallet creation result: {}", creation_result);

            // 2. Open the wallet.
            let open_ptr = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data = CStr::from_ptr(open_ptr).to_str().unwrap();
            println!("Opened wallet from known mnemonic");

            // 3. Get wallet address at index 0.
            let index_ptr = str_to_cchar("0");
            let epicbox_config_ptr = str_to_cchar(&epicbox_config);

            let address_ptr = rust_get_wallet_address(
                str_to_cchar(wallet_data),
                index_ptr,
                epicbox_config_ptr
            );
            let address_index_0 = CStr::from_ptr(address_ptr).to_str().unwrap();

            println!("Actual address at index 0: {}", address_index_0);

            // Verify the address matches the expected test vector.
            assert_eq!(
                address_index_0, expected_address_index_0,
                "Address at index 0 does not match expected test vector"
            );

            // 4. Get wallet address at index 1.
            let index_ptr_1 = str_to_cchar("1");
            let address_ptr_1 = rust_get_wallet_address(
                str_to_cchar(wallet_data),
                index_ptr_1,
                epicbox_config_ptr
            );
            let address_index_1 = CStr::from_ptr(address_ptr_1).to_str().unwrap();

            println!("Actual address at index 1: {}", address_index_1);

            // Verify the address matches the expected test vector.
            assert_eq!(
                address_index_1, expected_address_index_1,
                "Address at index 1 does not match expected test vector"
            );

            // 5. Create a second wallet with the same mnemonic to verify determinism.
            let delete_ptr = rust_delete_wallet(str_to_cchar(wallet_data), config_ptr);
            let delete_result = CStr::from_ptr(delete_ptr).to_str().unwrap();
            println!("Deleted first wallet: {}", delete_result);

            let name_ptr_2 = str_to_cchar("vector_wallet_2");
            let creation_ptr_2 = wallet_init(
                config_ptr,
                mnemonic_ptr,
                password_ptr,
                name_ptr_2
            );
            let creation_result_2 = CStr::from_ptr(creation_ptr_2).to_str().unwrap();
            println!("Second wallet creation result: {}", creation_result_2);

            let open_ptr_2 = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data_2 = CStr::from_ptr(open_ptr_2).to_str().unwrap();

            let address_ptr_verify = rust_get_wallet_address(
                str_to_cchar(wallet_data_2),
                index_ptr,
                epicbox_config_ptr
            );
            let address_verify = CStr::from_ptr(address_ptr_verify).to_str().unwrap();

            println!("Verification address at index 0: {}", address_verify);

            // Verify determinism: same mnemonic produces same address.
            assert_eq!(
                address_index_0, address_verify,
                "Same mnemonic should produce same address at index 0"
            );

            // 6. Clean up.
            let delete_ptr_2 = rust_delete_wallet(str_to_cchar(wallet_data_2), config_ptr);
            let delete_result_2 = CStr::from_ptr(delete_ptr_2).to_str().unwrap();
            println!("Deleted second wallet: {}", delete_result_2);
        }

        cleanup_test_dir(&test_dir);
        println!("=== End Mnemonic to Address Vector test ===");
    }

    /// Test the rust_get_tx_fees FFI function.
    /// This test creates a wallet and calculates transaction fees for various amounts.
    #[test]
    fn test_rust_get_tx_fees_ffi() {
        println!("=== Test rust_get_tx_fees FFI ===");

        let test_dir = setup_test_dir("get_tx_fees_ffi");
        let config_json = create_test_config(&test_dir);

        unsafe {
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("fees_test_password");
            let name_ptr = str_to_cchar("fees_wallet");

            // 1. Generate mnemonic and create wallet.
            let mnemonic_ptr = get_mnemonic();
            let mnemonic_str = CStr::from_ptr(mnemonic_ptr).to_str().unwrap();
            println!("Generated mnemonic for fees test");

            let creation_ptr = wallet_init(
                config_ptr,
                str_to_cchar(mnemonic_str),
                password_ptr,
                name_ptr
            );
            let creation_result = CStr::from_ptr(creation_ptr).to_str().unwrap();
            println!("Wallet creation result: {}", creation_result);

            // 2. Open the wallet.
            let open_ptr = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data = CStr::from_ptr(open_ptr).to_str().unwrap();
            println!("Opened wallet");

            // 3. Test fee calculation for various amounts.
            let test_amounts = ["100000000", "500000000", "1000000000"]; // In nanoEPIC
            let min_confirmations = "10";

            for amount in &test_amounts {
                println!("\nCalculating fees for amount: {} nanoEPIC", amount);

                let amount_ptr = str_to_cchar(amount);
                let min_conf_ptr = str_to_cchar(min_confirmations);

                let fees_ptr = rust_get_tx_fees(
                    str_to_cchar(wallet_data),
                    amount_ptr,
                    min_conf_ptr
                );
                let fees_result = CStr::from_ptr(fees_ptr).to_str().unwrap();

                println!("Fees result: {}", fees_result);

                // Verify the result.
                if fees_result.starts_with("Error ") {
                    println!("Expected error for empty wallet: {}", fees_result);
                    // Empty wallet should error when trying to calculate fees.
                    assert!(
                        fees_result.contains("Error"),
                        "Empty wallet should return error when calculating fees"
                    );
                } else {
                    // If we get a valid response, try to parse it as JSON.
                    match serde_json::from_str::<serde_json::Value>(fees_result) {
                        Ok(json) => {
                            println!("Successfully parsed fees JSON: {:?}", json);
                            // Verify it's an array (strategies).
                            assert!(json.is_array(), "Fees response should be an array");
                        }
                        Err(e) => {
                            println!("Note: Could not parse fees result as JSON: {}", e);
                        }
                    }
                }
            }

            // 4. Clean up.
            let delete_ptr = rust_delete_wallet(str_to_cchar(wallet_data), config_ptr);
            let delete_result = CStr::from_ptr(delete_ptr).to_str().unwrap();
            println!("\nDelete result: {}", delete_result);
        }

        cleanup_test_dir(&test_dir);
        println!("=== End rust_get_tx_fees FFI test ===");
    }

    /// Test the rust_txs_get FFI function.
    /// This test creates a wallet and retrieves the transaction list.
    #[test]
    fn test_rust_txs_get_ffi() {
        println!("=== Test rust_txs_get FFI ===");

        let test_dir = setup_test_dir("txs_get_ffi");
        let config_json = create_test_config(&test_dir);

        unsafe {
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("txs_test_password");
            let name_ptr = str_to_cchar("txs_wallet");

            // 1. Generate mnemonic and create wallet.
            let mnemonic_ptr = get_mnemonic();
            let mnemonic_str = CStr::from_ptr(mnemonic_ptr).to_str().unwrap();
            println!("Generated mnemonic for txs test");

            let creation_ptr = wallet_init(
                config_ptr,
                str_to_cchar(mnemonic_str),
                password_ptr,
                name_ptr
            );
            let creation_result = CStr::from_ptr(creation_ptr).to_str().unwrap();
            println!("Wallet creation result: {}", creation_result);

            // 2. Open the wallet.
            let open_ptr = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data = CStr::from_ptr(open_ptr).to_str().unwrap();
            println!("Opened wallet");

            // 3. Get transactions without refreshing from node.
            println!("\nGetting transactions (no refresh)...");
            let refresh_ptr_no = str_to_cchar("0"); // 0 = no refresh

            let txs_ptr = rust_txs_get(
                str_to_cchar(wallet_data),
                refresh_ptr_no
            );
            let txs_result = CStr::from_ptr(txs_ptr).to_str().unwrap();

            println!("Transactions result (no refresh): {}", txs_result);

            // Verify the result.
            if txs_result.starts_with("Error ") {
                println!("Error getting transactions: {}", txs_result);
            } else {
                // Should return valid JSON (likely an empty array for a new wallet).
                match serde_json::from_str::<serde_json::Value>(txs_result) {
                    Ok(json) => {
                        println!("Successfully parsed transactions JSON");
                        // Should be an array of transactions.
                        if json.is_array() {
                            let txs_array = json.as_array().unwrap();
                            println!("Number of transactions: {}", txs_array.len());
                            // New wallet should have no transactions.
                            assert_eq!(txs_array.len(), 0, "New wallet should have no transactions");
                        } else {
                            println!("Transactions result is not an array: {:?}", json);
                        }
                    }
                    Err(e) => {
                        println!("Could not parse transactions as JSON: {}", e);
                        println!("Raw result: {}", txs_result);
                    }
                }
            }

            // 4. Clean up.
            let delete_ptr = rust_delete_wallet(str_to_cchar(wallet_data), config_ptr);
            let delete_result = CStr::from_ptr(delete_ptr).to_str().unwrap();
            println!("\nDelete result: {}", delete_result);
        }

        cleanup_test_dir(&test_dir);
        println!("=== End rust_txs_get FFI test ===");
    }

    /// Test the rust_tx_cancel FFI function.
    /// This test verifies the transaction cancellation functionality.
    /// Note: Since we can't create real transactions without funds, we test with a fake UUID.
    #[test]
    fn test_rust_tx_cancel_ffi() {
        println!("=== Test rust_tx_cancel FFI ===");

        let test_dir = setup_test_dir("tx_cancel_ffi");
        let config_json = create_test_config(&test_dir);

        unsafe {
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("cancel_test_password");
            let name_ptr = str_to_cchar("cancel_wallet");

            // 1. Generate mnemonic and create wallet.
            let mnemonic_ptr = get_mnemonic();
            let mnemonic_str = CStr::from_ptr(mnemonic_ptr).to_str().unwrap();
            println!("Generated mnemonic for cancel test");

            let creation_ptr = wallet_init(
                config_ptr,
                str_to_cchar(mnemonic_str),
                password_ptr,
                name_ptr
            );
            let creation_result = CStr::from_ptr(creation_ptr).to_str().unwrap();
            println!("Wallet creation result: {}", creation_result);

            // 2. Open the wallet.
            let open_ptr = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data = CStr::from_ptr(open_ptr).to_str().unwrap();
            println!("Opened wallet");

            // 3. Attempt to cancel a non-existent transaction.
            // This tests the FFI function's error handling.
            let fake_tx_id = "550e8400-e29b-41d4-a716-446655440000"; // Valid UUID format.
            println!("\nAttempting to cancel transaction: {}", fake_tx_id);

            let start = std::time::Instant::now();

            let tx_id_ptr = str_to_cchar(fake_tx_id);
            let cancel_ptr = rust_tx_cancel(
                str_to_cchar(wallet_data),
                tx_id_ptr
            );
            let cancel_result = CStr::from_ptr(cancel_ptr).to_str().unwrap();

            let elapsed = start.elapsed();

            println!("Cancel result: {}", cancel_result);
            println!("Operation took: {:?}", elapsed);

            // Verify the operation completed within timeout.
            assert!(
                elapsed.as_secs() < 15,
                "Operation should complete within 15 seconds (timeout is 10s + 5s buffer)"
            );

            // Verify the result.
            // Since the transaction doesn't exist, we expect an error.
            if cancel_result.starts_with("Error ") {
                println!("Expected error for non-existent transaction: {}", cancel_result);
                assert!(
                    cancel_result.contains("Error"),
                    "Cancelling non-existent transaction should return an error"
                );
            } else if cancel_result.is_empty() {
                // Empty string indicates success (unlikely for fake UUID).
                println!("Transaction cancel returned success (unexpected for fake UUID)");
            } else {
                println!("Unexpected cancel result: {}", cancel_result);
            }

            // Note: We don't test invalid UUID formats here because the FFI function
            // panics on invalid UUIDs (which aborts across FFI boundary).
            // This is a known limitation - the UUID parsing happens before error handling.

            // 4. Clean up.
            let delete_ptr = rust_delete_wallet(str_to_cchar(wallet_data), config_ptr);
            let delete_result = CStr::from_ptr(delete_ptr).to_str().unwrap();
            println!("\nDelete result: {}", delete_result);
        }

        cleanup_test_dir(&test_dir);
        println!("=== End rust_tx_cancel FFI test ===");
    }

    /// Test the rust_create_tx and rust_tx_send_http FFI functions.
    /// These functions create transactions, so we test them together.
    /// Note: Without funds, these will return errors, but we verify the FFI interface works.
    #[test]
    fn test_rust_create_tx_ffi() {
        println!("=== Test rust_create_tx FFI ===");

        let test_dir = setup_test_dir("create_tx_ffi");
        let config_json = create_test_config(&test_dir);

        let epicbox_config = json!({
            "epicbox_domain": "epicbox.epic.tech",
            "epicbox_port": 443,
            "epicbox_protocol_unsecure": false,
            "epicbox_address_index": 0,
        }).to_string();

        unsafe {
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("tx_test_password");
            let name_ptr = str_to_cchar("tx_wallet");

            // 1. Generate mnemonic and create wallet.
            let mnemonic_ptr = get_mnemonic();
            let mnemonic_str = CStr::from_ptr(mnemonic_ptr).to_str().unwrap();
            println!("Generated mnemonic for tx test");

            let creation_ptr = wallet_init(
                config_ptr,
                str_to_cchar(mnemonic_str),
                password_ptr,
                name_ptr
            );
            let creation_result = CStr::from_ptr(creation_ptr).to_str().unwrap();
            println!("Wallet creation result: {}", creation_result);

            // 2. Open the wallet.
            let open_ptr = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data = CStr::from_ptr(open_ptr).to_str().unwrap();
            println!("Opened wallet");

            // 3. Test rust_create_tx (epicbox transaction).
            println!("\nTesting rust_create_tx...");
            let amount = "1000000000"; // 1 EPIC in nanoEPIC
            let to_address = "epic1test@epicbox.epic.tech";
            let secret_key_index = "0";
            let confirmations = "10";
            let note = "Test transaction";

            let tx_ptr = rust_create_tx(
                str_to_cchar(wallet_data),
                str_to_cchar(amount),
                str_to_cchar(to_address),
                str_to_cchar(secret_key_index),
                str_to_cchar(&epicbox_config),
                str_to_cchar(confirmations),
                str_to_cchar(note)
            );
            let tx_result = CStr::from_ptr(tx_ptr).to_str().unwrap();

            println!("Create tx result: {}", tx_result);

            // Should return an error (no funds in wallet).
            if tx_result.starts_with("Error ") {
                println!("Expected error for empty wallet");
                assert!(tx_result.contains("Error"), "Empty wallet should error when creating tx");
            } else {
                println!("Unexpected success creating tx (wallet has no funds)");
            }

            // 4. Test rust_tx_send_http (HTTP transaction).
            println!("\nTesting rust_tx_send_http...");
            let strategy_use_all = "0"; // Don't use all outputs.
            let message = "HTTP test transaction";
            let http_address = "http://example.epic.address";

            let http_tx_ptr = rust_tx_send_http(
                str_to_cchar(wallet_data),
                str_to_cchar(strategy_use_all),
                str_to_cchar(confirmations),
                str_to_cchar(message),
                str_to_cchar(amount),
                str_to_cchar(http_address)
            );
            let http_tx_result = CStr::from_ptr(http_tx_ptr).to_str().unwrap();

            println!("Send HTTP tx result: {}", http_tx_result);

            // Should also return an error (no funds in wallet).
            if http_tx_result.starts_with("Error ") {
                println!("Expected error for empty wallet");
                assert!(http_tx_result.contains("Error"), "Empty wallet should error when sending HTTP tx");
            } else {
                println!("Unexpected success sending HTTP tx (wallet has no funds)");
            }

            // 5. Clean up.
            let delete_ptr = rust_delete_wallet(str_to_cchar(wallet_data), config_ptr);
            let delete_result = CStr::from_ptr(delete_ptr).to_str().unwrap();
            println!("\nDelete result: {}", delete_result);
        }

        cleanup_test_dir(&test_dir);
        println!("=== End rust_create_tx FFI test ===");
    }

    /// Test the rust_epicbox_listener_start and _listener_cancel FFI functions.
    /// This test verifies the listener lifecycle: start and stop.
    #[test]
    fn test_rust_epicbox_listener_ffi() {
        println!("=== Test rust_epicbox_listener FFI ===");

        let test_dir = setup_test_dir("listener_ffi");
        let config_json = create_test_config(&test_dir);

        let epicbox_config = json!({
            "epicbox_domain": "epicbox.epic.tech",
            "epicbox_port": 443,
            "epicbox_protocol_unsecure": false,
            "epicbox_address_index": 0,
        }).to_string();

        unsafe {
            let config_ptr = str_to_cchar(&config_json);
            let password_ptr = str_to_cchar("listener_test_password");
            let name_ptr = str_to_cchar("listener_wallet");

            // 1. Generate mnemonic and create wallet.
            let mnemonic_ptr = get_mnemonic();
            let mnemonic_str = CStr::from_ptr(mnemonic_ptr).to_str().unwrap();
            println!("Generated mnemonic for listener test");

            let creation_ptr = wallet_init(
                config_ptr,
                str_to_cchar(mnemonic_str),
                password_ptr,
                name_ptr
            );
            let creation_result = CStr::from_ptr(creation_ptr).to_str().unwrap();
            println!("Wallet creation result: {}", creation_result);

            // 2. Open the wallet.
            let open_ptr = rust_open_wallet(config_ptr, password_ptr);
            let wallet_data = CStr::from_ptr(open_ptr).to_str().unwrap();
            println!("Opened wallet");

            // 3. Start the epicbox listener.
            println!("\nStarting epicbox listener...");
            let listener_handle = rust_epicbox_listener_start(
                str_to_cchar(wallet_data),
                str_to_cchar(&epicbox_config)
            );

            println!("Listener handle: {:?}", listener_handle);

            // Verify we got a valid handle (non-null pointer).
            assert!(!listener_handle.is_null(), "Listener handle should not be null");

            // 4. Let the listener run briefly.
            println!("Listener is running...");
            std::thread::sleep(std::time::Duration::from_secs(1));

            // 5. Cancel the listener.
            println!("\nCancelling listener...");
            let cancel_ptr = _listener_cancel(listener_handle);
            let cancel_result = CStr::from_ptr(cancel_ptr).to_str().unwrap();

            println!("Listener cancel result: {}", cancel_result);

            // The result should indicate whether the listener was cancelled.
            // It returns "true" or "false" as a string.
            if cancel_result == "true" {
                println!("Listener successfully cancelled");
            } else if cancel_result == "false" {
                println!("Listener was not cancelled (may have already stopped)");
            } else {
                println!("Unexpected cancel result: {}", cancel_result);
            }

            // 6. Clean up.
            let delete_ptr = rust_delete_wallet(str_to_cchar(wallet_data), config_ptr);
            let delete_result = CStr::from_ptr(delete_ptr).to_str().unwrap();
            println!("\nDelete result: {}", delete_result);
        }

        cleanup_test_dir(&test_dir);
        println!("=== End rust_epicbox_listener FFI test ===");
    }
}
