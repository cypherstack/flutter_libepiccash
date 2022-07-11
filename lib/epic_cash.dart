import 'package:flutter/material.dart';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'dart:io' as io;

const base = 'greeter';
final DynamicLibrary epicCashNative =
    io.Platform.isAndroid || io.Platform.isLinux
        ? DynamicLibrary.open("libepic_cash_wallet.so")
        : DynamicLibrary.process();

typedef WalletMnemonic = Pointer<Utf8> Function();
typedef WalletMnemonicFFI = Pointer<Utf8> Function();

typedef WalletInit = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef WalletInitFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef WalletInfo = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>);
typedef WalletInfoFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>);

typedef RecoverWallet = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef RecoverWalletFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef WalletPhrase = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef WalletPhraseFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef ScanOutPuts = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>);
typedef ScanOutPutsFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>);

typedef CreateTransaction = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>, Pointer<Int8>);
typedef CreateTransactionFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>, Pointer<Int8>);

typedef GetTransactions = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);
typedef GetTransactionsFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);

typedef CancelTransaction = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>);
typedef CancelTransactionFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Int8>);

typedef ReceiveTransaction = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef ReceiveTransactionFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef GetChainHeight = Pointer<Utf8> Function(
    Pointer<Utf8>);
typedef GetChainHeightFFI = Pointer<Utf8> Function(
    Pointer<Utf8>);

final Pointer<Utf8> Function() walletMnemonic = epicCashNative
    .lookup<NativeFunction<Pointer<Utf8> Function()>>("get_mnemonic")
    .asFunction();

final WalletInit initWallet = epicCashNative
    .lookup<NativeFunction<WalletInitFFI>>("wallet_init")
    .asFunction();

final WalletInfo _walletInfo = epicCashNative
    .lookup<NativeFunction<WalletInfoFFI>>("rust_wallet_balances")
    .asFunction();

String getWalletInfo(String config, String password, int refreshFromNode) {
    return _walletInfo(
        config.toNativeUtf8(), password.toNativeUtf8(),
        refreshFromNode.toString().toNativeUtf8().cast<Int8>()
    ).toDartString();
}

final RecoverWallet recoverWallet = epicCashNative
    .lookup<NativeFunction<RecoverWalletFFI>>("rust_recover_from_mnemonic")
    .asFunction();

final WalletPhrase walletPhrase = epicCashNative
    .lookup<NativeFunction<WalletPhraseFFI>>("rust_wallet_phrase")
    .asFunction();

final ScanOutPuts _scanOutPuts = epicCashNative
    .lookup<NativeFunction<ScanOutPutsFFI>>("rust_wallet_scan_outputs")
    .asFunction();

String scanOutPuts(String config, String password, int startHeight) {
    return _scanOutPuts(
        config.toNativeUtf8(), password.toNativeUtf8(), startHeight.toString().toNativeUtf8().cast<Int8>()
    ).toDartString();
}

final CreateTransaction createTransaction = epicCashNative
    .lookup<NativeFunction<CreateTransactionFFI>>("rust_create_tx")
    .asFunction();

final GetTransactions getTransactions = epicCashNative
    .lookup<NativeFunction<GetTransactionsFFI>>("rust_txs_get")
    .asFunction();

final CancelTransaction cancelTransaction = epicCashNative
    .lookup<NativeFunction<CancelTransactionFFI>>("rust_tx_cancel")
    .asFunction();

final ReceiveTransaction receiveTransaction = epicCashNative
    .lookup<NativeFunction<ReceiveTransactionFFI>>("rust_tx_receive")
    .asFunction();

final GetChainHeight _getChainHeight = epicCashNative
    .lookup<NativeFunction<GetChainHeightFFI>>("rust_get_chain_height")
    .asFunction();

int getChainHeight(String config) {
    String chainHeight = _getChainHeight(config.toNativeUtf8()).toDartString();
    return int.parse(chainHeight);
}