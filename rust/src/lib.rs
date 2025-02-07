use stack_epic_wallet_libwallet::Error;
use stack_epic_wallet_controller::Error as EpicWalletControllerError;

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
