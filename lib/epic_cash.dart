import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'src/epic_cash_wallet_bindings.g.dart' as native;

void _freeRustString(Pointer<Char>? value) {
  if (value != null) {
    native.epic_cash_string_free(value);
  }
}

Pointer<Char> _toNativeChar(String value) => value.toNativeUtf8().cast();

String _fromNativeChar(Pointer<Char> value) =>
    value.cast<Utf8>().toDartString();

String walletMnemonic() {
  Pointer<Char>? ptr;
  try {
    ptr = native.get_mnemonic();
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    _freeRustString(ptr);
  }
}

String initWallet(
  String config,
  String mnemonic,
  String password,
  String name,
) {
  Pointer<Char>? ptr;
  final configPtr = _toNativeChar(config);
  final mnemonicPtr = _toNativeChar(mnemonic);
  final passwordPtr = _toNativeChar(password);
  final namePtr = _toNativeChar(name);

  try {
    ptr = native.wallet_init(configPtr, mnemonicPtr, passwordPtr, namePtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    malloc.free(mnemonicPtr);
    malloc.free(passwordPtr);
    malloc.free(namePtr);
    _freeRustString(ptr);
  }
}

Future<String> getWalletInfo(
  String wallet,
  int refreshFromNode,
  int minimumConfirmations,
) async {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final refreshFromNodePtr = _toNativeChar(refreshFromNode.toString());
  final minConfPtr = _toNativeChar(minimumConfirmations.toString());

  try {
    ptr = native.rust_wallet_balances(
      walletPtr,
      refreshFromNodePtr,
      minConfPtr,
    );
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(refreshFromNodePtr);
    malloc.free(minConfPtr);
    _freeRustString(ptr);
  }
}

String recoverWallet(
  String config,
  String password,
  String mnemonic,
  String name,
) {
  Pointer<Char>? ptr;
  final configPtr = _toNativeChar(config);
  final passwordPtr = _toNativeChar(password);
  final mnemonicPtr = _toNativeChar(mnemonic);
  final namePtr = _toNativeChar(name);

  try {
    ptr = native.rust_recover_from_mnemonic(
      configPtr,
      passwordPtr,
      mnemonicPtr,
      namePtr,
    );
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    malloc.free(passwordPtr);
    malloc.free(mnemonicPtr);
    malloc.free(namePtr);
    _freeRustString(ptr);
  }
}

Future<String> scanOutPuts(
  String wallet,
  int startHeight,
  int numberOfBlocks,
) async {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final startHeightPtr = _toNativeChar(startHeight.toString());
  final numberOfBlocksPtr = _toNativeChar(numberOfBlocks.toString());

  try {
    ptr = native.rust_wallet_scan_outputs(
      walletPtr,
      startHeightPtr,
      numberOfBlocksPtr,
    );
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(startHeightPtr);
    malloc.free(numberOfBlocksPtr);
    _freeRustString(ptr);
  }
}

Pointer<Void> epicboxListenerStart(String wallet, String epicboxConfig) {
  final walletPtr = _toNativeChar(wallet);
  final epicboxConfigPtr = _toNativeChar(epicboxConfig);

  try {
    return native.rust_epicbox_listener_start(walletPtr, epicboxConfigPtr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(epicboxConfigPtr);
  }
}

bool epicboxListenerStop(Pointer<Void> handler) {
  Pointer<Char>? ptr;

  try {
    ptr = native.epic_cash_listener_cancel(handler);
    return _fromNativeChar(ptr) == "true";
  } catch (_) {
    return false;
  } finally {
    _freeRustString(ptr);
  }
}

/// Check if the epicbox listener is still running.
/// Returns true if the listener is alive, false if it has stopped or handler is null.
bool epicboxListenerIsRunning(Pointer<Void>? handler) {
  if (handler == null) {
    return false;
  }

  Pointer<Char>? ptr;

  try {
    ptr = native.epic_cash_listener_is_running(handler);
    return _fromNativeChar(ptr) == "true";
  } catch (_) {
    return false;
  } finally {
    _freeRustString(ptr);
  }
}

Future<String> createTransaction(
  String wallet,
  int amount,
  String address,
  int secretKey,
  String epicboxConfig,
  int minimumConfirmations,
  String note, {
  bool returnSlate = false,
}) async {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final amountPtr = _toNativeChar(amount.toString());
  final addressPtr = _toNativeChar(address);
  final secretKeyPtr = _toNativeChar(secretKey.toString());
  final epicboxConfigPtr = _toNativeChar(epicboxConfig);
  final minConfPtr = _toNativeChar(minimumConfirmations.toString());
  final notePtr = _toNativeChar(note);
  final returnSlatePtr = _toNativeChar(returnSlate ? '1' : '0');

  try {
    ptr = native.rust_create_tx(
      walletPtr,
      amountPtr,
      addressPtr,
      secretKeyPtr,
      epicboxConfigPtr,
      minConfPtr,
      notePtr,
      returnSlatePtr,
    );
    return _fromNativeChar(ptr);
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
    malloc.free(returnSlatePtr);
    _freeRustString(ptr);
  }
}

Future<String> getTransactions(String wallet, int refreshFromNode) async {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final refreshFromNodePtr = _toNativeChar(refreshFromNode.toString());

  try {
    ptr = native.rust_txs_get(walletPtr, refreshFromNodePtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(refreshFromNodePtr);
    _freeRustString(ptr);
  }
}

String cancelTransaction(String wallet, String transactionId) {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final transactionIdPtr = _toNativeChar(transactionId);

  try {
    ptr = native.rust_tx_cancel(walletPtr, transactionIdPtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(transactionIdPtr);
    _freeRustString(ptr);
  }
}

int getChainHeight(String config) {
  Pointer<Char>? ptr;
  final configPtr = _toNativeChar(config);

  try {
    ptr = native.rust_get_chain_height(configPtr);
    final latestHeight = _fromNativeChar(ptr);
    return int.parse(latestHeight);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    _freeRustString(ptr);
  }
}

String getAddressInfo(String wallet, int index, String epicboxConfig) {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final indexPtr = _toNativeChar(index.toString());
  final epicboxConfigPtr = _toNativeChar(epicboxConfig);

  try {
    ptr = native.rust_get_wallet_address(walletPtr, indexPtr, epicboxConfigPtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(indexPtr);
    malloc.free(epicboxConfigPtr);
    _freeRustString(ptr);
  }
}

String validateSendAddress(String address) {
  Pointer<Char>? ptr;
  final addressPtr = _toNativeChar(address);

  try {
    ptr = native.rust_validate_address(addressPtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(addressPtr);
    _freeRustString(ptr);
  }
}

Future<String> getTransactionFees(
  String wallet,
  int amount,
  int minimumConfirmations,
) async {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final amountPtr = _toNativeChar(amount.toString());
  final minConfPtr = _toNativeChar(minimumConfirmations.toString());

  try {
    ptr = native.rust_get_tx_fees(walletPtr, amountPtr, minConfPtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(amountPtr);
    malloc.free(minConfPtr);
    _freeRustString(ptr);
  }
}

Future<String> deleteWallet(String wallet, String config) async {
  Pointer<Char>? ptr;
  final configPtr = _toNativeChar(config);
  final walletPtr = _toNativeChar(wallet);
  try {
    ptr = native.rust_delete_wallet(walletPtr, configPtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    malloc.free(walletPtr);
    _freeRustString(ptr);
  }
}

String openWallet(String config, String password) {
  Pointer<Char>? ptr;
  final configPtr = _toNativeChar(config);
  final pwPtr = _toNativeChar(password);
  try {
    ptr = native.rust_open_wallet(configPtr, pwPtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(configPtr);
    malloc.free(pwPtr);
    _freeRustString(ptr);
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
  Pointer<Char>? ptr;

  final walletPtr = _toNativeChar(wallet);
  final stratPtr = _toNativeChar(selectionStrategyIsAll.toString());
  final minConfsPtr = _toNativeChar(minimumConfirmations.toString());
  final messagePtr = _toNativeChar(message);
  final amountPtr = _toNativeChar(amount.toString());
  final addressPtr = _toNativeChar(address);

  try {
    ptr = native.rust_tx_send_http(
      walletPtr,
      stratPtr,
      minConfsPtr,
      messagePtr,
      amountPtr,
      addressPtr,
    );

    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(stratPtr);
    malloc.free(minConfsPtr);
    malloc.free(messagePtr);
    malloc.free(amountPtr);
    malloc.free(addressPtr);
    _freeRustString(ptr);
  }
}

/// Receive a slate (step 2 of 3-part transaction).
///
/// The receiver opens an incoming slate, adds its output and partial signature,
/// then returns the updated slate.
String txReceive(String wallet, String slateJson) {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final slateJsonPtr = _toNativeChar(slateJson);

  try {
    ptr = native.rust_tx_receive(walletPtr, slateJsonPtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(slateJsonPtr);
    _freeRustString(ptr);
  }
}

/// Finalize a slate (step 3 of 3-part transaction).
///
/// The original sender finalizes the transaction with the receiver's response
/// and broadcasts it to the network.
String txFinalize(String wallet, String slateJson) {
  Pointer<Char>? ptr;
  final walletPtr = _toNativeChar(wallet);
  final slateJsonPtr = _toNativeChar(slateJson);

  try {
    ptr = native.rust_tx_finalize(walletPtr, slateJsonPtr);
    return _fromNativeChar(ptr);
  } catch (_) {
    rethrow;
  } finally {
    malloc.free(walletPtr);
    malloc.free(slateJsonPtr);
    _freeRustString(ptr);
  }
}
