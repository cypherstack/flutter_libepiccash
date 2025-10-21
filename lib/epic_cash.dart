import 'dart:ffi';
import 'dart:io' as io;

import 'package:ffi/ffi.dart';
import 'src/bindings_generated.dart';

DynamicLibrary _openEpicLib() {
  if (io.Platform.isWindows) {
    try {
      return DynamicLibrary.open('libepic_cash_wallet.dll');
    } catch (_) {
      // Fallback to common Windows naming without lib- prefix
      return DynamicLibrary.open('epic_cash_wallet.dll');
    }
  }

  if (io.Platform.isAndroid || io.Platform.isLinux) {
    // Expect library at script build outputs; fall back to name.
    const candidates = [
      'linux/bin/x86_64-unknown-linux-gnu/release/libepic_cash_wallet.so',
      'linux/bin/aarch64-unknown-linux-gnu/release/libepic_cash_wallet.so',
      'libepic_cash_wallet.so',
    ];
    for (final path in candidates) {
      if (io.File(path).existsSync()) {
        return DynamicLibrary.open(path);
      }
    }
    // Final fallback lets system search path/LD_LIBRARY_PATH resolve it.
    return DynamicLibrary.open('libepic_cash_wallet.so');
  }

  // For iOS/macOS when statically linked.
  return DynamicLibrary.process();
}

final DynamicLibrary epicCashNative = _openEpicLib();

final EpicCashWalletBindings _bindings = EpicCashWalletBindings(epicCashNative);

String walletMnemonic() {
  Pointer<Utf8>? ptr;
  try {
    ptr = _bindings.get_mnemonic().cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

String initWallet(
  String config,
  String mnemonic,
  String password,
  String name,
) {
  Pointer<Utf8>? ptr;
  final configPtr = config.toNativeUtf8();
  final mnemonicPtr = mnemonic.toNativeUtf8();
  final passwordPtr = password.toNativeUtf8();
  final namePtr = name.toNativeUtf8();

  try {
    ptr = _bindings
        .wallet_init(
          configPtr.cast(),
          mnemonicPtr.cast(),
          passwordPtr.cast(),
          namePtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    malloc.free(mnemonicPtr);
    malloc.free(passwordPtr);
    malloc.free(namePtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

Future<String> getWalletInfo(
  String wallet,
  int refreshFromNode,
  int min_confirmations,
) async {
  Pointer<Utf8>? ptr;
  final walletPtr = wallet.toNativeUtf8();
  final refreshFromNodePtr =
      refreshFromNode.toString().toNativeUtf8().cast<Int8>();
  final minConfPtr = min_confirmations.toString().toNativeUtf8().cast<Int8>();

  try {
    ptr = _bindings
        .rust_wallet_balances_json(
          walletPtr.cast(),
          refreshFromNodePtr.cast(),
          minConfPtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(refreshFromNodePtr);
    malloc.free(minConfPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

String recoverWallet(
  String config,
  String password,
  String mnemonic,
  String name,
) {
  Pointer<Utf8>? ptr;
  final configPtr = config.toNativeUtf8();
  final passwordPtr = password.toNativeUtf8();
  final mnemonicPtr = mnemonic.toNativeUtf8();
  final namePtr = name.toNativeUtf8();

  try {
    ptr = _bindings
        .rust_recover_from_mnemonic(
          configPtr.cast(),
          passwordPtr.cast(),
          mnemonicPtr.cast(),
          namePtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    malloc.free(passwordPtr);
    malloc.free(mnemonicPtr);
    malloc.free(namePtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

Future<String> scanOutPuts(
  String wallet,
  int startHeight,
  int numberOfBlocks,
) async {
  Pointer<Utf8>? ptr;
  final walletPtr = wallet.toNativeUtf8();
  final startHeightPtr = startHeight.toString().toNativeUtf8().cast<Int8>();
  final numberOfBlocksPtr =
      numberOfBlocks.toString().toNativeUtf8().cast<Int8>();

  try {
    ptr = _bindings
        .rust_wallet_scan_outputs_json(
          walletPtr.cast(),
          startHeightPtr.cast(),
          numberOfBlocksPtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(startHeightPtr);
    malloc.free(numberOfBlocksPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

Pointer<Void> epicboxListenerStart(String wallet, String epicboxConfig) {
  final walletPtr = wallet.toNativeUtf8();
  final epicboxConfigPtr = epicboxConfig.toNativeUtf8();

  try {
    return _bindings
        .rust_epicbox_listener_start(
          walletPtr.cast(),
          epicboxConfigPtr.cast(),
        )
        .cast<Void>();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(epicboxConfigPtr);
  }
}

String epicboxListenerStop(Pointer<Void> handler) {
  Pointer<Utf8>? ptr;

  try {
    ptr = _bindings.listener_cancel(handler.cast()).cast<Utf8>();
    return ptr!.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

Future<String> createTransaction(
  String wallet,
  int amount,
  String address,
  int secretKey,
  String epicboxConfig,
  int minimumConfirmations,
  String note,
) async {
  Pointer<Utf8>? ptr;
  final walletPtr = wallet.toNativeUtf8();
  final amountPtr = amount.toString().toNativeUtf8().cast<Int8>();
  final addressPtr = address.toNativeUtf8();
  final secretKeyPtr = secretKey.toString().toNativeUtf8().cast<Int8>();
  final epicboxConfigPtr = epicboxConfig.toNativeUtf8();
  final minConfPtr =
      minimumConfirmations.toString().toNativeUtf8().cast<Int8>();
  final notePtr = note.toNativeUtf8();

  try {
    ptr = _bindings
        .rust_create_tx_json(
          walletPtr.cast(),
          amountPtr.cast(),
          addressPtr.cast(),
          secretKeyPtr.cast(),
          epicboxConfigPtr.cast(),
          minConfPtr.cast(),
          notePtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(amountPtr);
    malloc.free(addressPtr);
    malloc.free(secretKeyPtr);
    malloc.free(epicboxConfigPtr);
    malloc.free(minConfPtr);
    malloc.free(notePtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

Future<String> getTransactions(String wallet, int refreshFromNode) async {
  Pointer<Utf8>? ptr;
  final walletPtr = wallet.toNativeUtf8();
  final refreshFromNodePtr =
      refreshFromNode.toString().toNativeUtf8().cast<Int8>();

  try {
    ptr = _bindings
        .rust_txs_get_json(
          walletPtr.cast(),
          refreshFromNodePtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(refreshFromNodePtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

String cancelTransaction(String wallet, String transactionId) {
  Pointer<Utf8>? ptr;
  final walletPtr = wallet.toNativeUtf8();
  final transactionIdPtr = transactionId.toNativeUtf8();

  try {
    ptr = _bindings
        .rust_tx_cancel_json(
          walletPtr.cast(),
          transactionIdPtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(transactionIdPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

int getChainHeight(String config) {
  Pointer<Utf8>? ptr;
  final configPtr = config.toNativeUtf8();

  try {
    ptr = _bindings.rust_get_chain_height(configPtr.cast()).cast<Utf8>();
    final latestHeight = ptr.toDartString();
    return int.parse(latestHeight);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

String getAddressInfo(String wallet, int index, String epicboxConfig) {
  Pointer<Utf8>? ptr;
  final walletPtr = wallet.toNativeUtf8();
  final indexPtr = index.toString().toNativeUtf8().cast<Int8>();
  final epicboxConfigPtr = epicboxConfig.toNativeUtf8();

  try {
    ptr = _bindings
        .rust_get_wallet_address_json(
          walletPtr.cast(),
          indexPtr.cast(),
          epicboxConfigPtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(indexPtr);
    malloc.free(epicboxConfigPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

String validateSendAddress(String address) {
  Pointer<Utf8>? ptr;
  final addressPtr = address.toNativeUtf8();

  try {
    ptr = _bindings.rust_validate_address(addressPtr.cast()).cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(addressPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

Future<String> getTransactionFees(
  String wallet,
  int amount,
  int minimumConfirmations,
) async {
  Pointer<Utf8>? ptr;
  final walletPtr = wallet.toNativeUtf8();
  final amountPtr = amount.toString().toNativeUtf8();
  final minConfPtr = minimumConfirmations.toString().toNativeUtf8();

  try {
    ptr = _bindings
        .rust_get_tx_fees_json(
          walletPtr.cast(),
          amountPtr.cast(),
          minConfPtr.cast(),
        )
        .cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(amountPtr);
    malloc.free(minConfPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

Future<String> deleteWallet(String wallet, String config) async {
  Pointer<Utf8>? ptr;
  final configPtr = config.toNativeUtf8();
  final walletPtr = wallet.toNativeUtf8();
  try {
    ptr = _bindings.rust_delete_wallet_json(walletPtr.cast(), configPtr.cast()).cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    malloc.free(walletPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

String openWallet(String config, String password) {
  Pointer<Utf8>? ptr;
  final configPtr = config.toNativeUtf8();
  final pwPtr = password.toNativeUtf8();
  try {
    ptr = _bindings.rust_open_wallet_json(configPtr.cast(), pwPtr.cast()).cast<Utf8>();
    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    malloc.free(pwPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}

Future<String> txHttpSend(
  String wallet,
  int selectionStrategyIsAll,
  int minimumConfirmations,
  String message,
  int amount,
  String address,
) async {
  Pointer<Utf8>? ptr;

  final walletPtr = wallet.toNativeUtf8();
  final stratPtr =
      selectionStrategyIsAll.toString().toNativeUtf8().cast<Int8>();
  final minConfsPtr =
      minimumConfirmations.toString().toNativeUtf8().cast<Int8>();
  final messagePtr = message.toNativeUtf8();
  final amountPtr = amount.toString().toNativeUtf8().cast<Int8>();
  final addressPtr = address.toNativeUtf8();

  try {
    ptr = _bindings
        .rust_tx_send_http_json(
          walletPtr.cast(),
          stratPtr.cast(),
          minConfsPtr.cast(),
          messagePtr.cast(),
          amountPtr.cast(),
          addressPtr.cast(),
        )
        .cast<Utf8>();

    return ptr.toDartString();
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(stratPtr);
    malloc.free(minConfsPtr);
    malloc.free(messagePtr);
    malloc.free(amountPtr);
    malloc.free(addressPtr);
    if (ptr != null) {
      _bindings.rust_string_free(ptr.cast());
    }
  }
}
