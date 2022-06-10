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

typedef WalletInfo = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef WalletInfoFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef RecoverWallet = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef RecoverWalletFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef WalletPhrase = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef WalletPhraseFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef ScanOutPuts = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef ScanOutPutsFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

final Pointer<Utf8> Function() walletMnemonic = epicCashNative
    .lookup<NativeFunction<Pointer<Utf8> Function()>>("get_mnemonic")
    .asFunction();

final WalletInit initWallet = epicCashNative
    .lookup<NativeFunction<WalletInitFFI>>("wallet_init")
    .asFunction();

final WalletInfo walletInfo = epicCashNative
    .lookup<NativeFunction<WalletInfoFFI>>("rust_wallet_balances")
    .asFunction();

final RecoverWallet recoverWallet = epicCashNative
    .lookup<NativeFunction<RecoverWalletFFI>>("rust_recover_from_mnemonic")
    .asFunction();

final WalletPhrase walletPhrase = epicCashNative
    .lookup<NativeFunction<WalletPhraseFFI>>("rust_wallet_phrase")
    .asFunction();

final ScanOutPuts scanOutPuts = epicCashNative
    .lookup<NativeFunction<ScanOutPutsFFI>>("rust_wallet_scan_outputs")
    .asFunction();
