import 'package:flutter/material.dart';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'dart:io' as io;

// import 'package:path';
// import 'package:permission_handler/permission_handler.dart';

const base = 'greeter';
final DynamicLibrary greeterNative = io.Platform.isAndroid
    ? DynamicLibrary.open("libepic_cash_wallet.so")
    : DynamicLibrary.process();

typedef GreetingFunction = Pointer<Utf8> Function(Pointer<Utf8>);
typedef GreetingFunctionFFI = Pointer<Utf8> Function(Pointer<Utf8>);

typedef WalletMnemonic = Pointer Function();
typedef WalletMnemonicFFI = Pointer Function();

final GreetingFunction rustGreeting = greeterNative
    .lookup<NativeFunction<GreetingFunctionFFI>>("string_from_rust")
    .asFunction();

final WalletMnemonic mnemonic = greeterNative
    .lookup<NativeFunction<WalletMnemonicFFI>>("get_mnemonic")
    .asFunction();
