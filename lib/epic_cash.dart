import 'dart:ffi';
import 'dart:io' as io;

import 'package:ffi/ffi.dart';

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
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);
typedef WalletInfoFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);

typedef RecoverWallet = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef RecoverWalletFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef WalletPhrase = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef WalletPhraseFFI = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef ScanOutPuts = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);
typedef ScanOutPutsFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);

typedef CreateTransaction = Pointer<Utf8> Function(Pointer<Utf8>,
    Pointer<Int8>, Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>, Pointer<Int8>);
typedef CreateTransactionFFI = Pointer<Utf8> Function(
    Pointer<Utf8>,
    Pointer<Int8>,
    Pointer<Utf8>,
    Pointer<Int8>,
    Pointer<Utf8>,
    Pointer<Int8>);

typedef GetTransactions = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>);
typedef GetTransactionsFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>);

typedef CancelTransaction = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef CancelTransactionFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);

typedef GetChainHeight = Pointer<Utf8> Function(Pointer<Utf8>);
typedef GetChainHeightFFI = Pointer<Utf8> Function(Pointer<Utf8>);

typedef AddressInfo = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);
typedef AddressInfoFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);

typedef ValidateAddress = Pointer<Utf8> Function(Pointer<Utf8>);
typedef ValidateAddressFFI = Pointer<Utf8> Function(Pointer<Utf8>);

typedef PendingSlates = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);
typedef PendingSlatesFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);

typedef SubscribeRequest = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);
typedef SubscribeRequestFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>);

typedef ProcessSlates = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef ProcessSlatesFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);

typedef TransactionFees = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);
typedef TransactionFeesFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Int8>, Pointer<Int8>);

typedef EncryptSlate = Pointer<Utf8> Function(Pointer<Utf8>,
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>, Pointer<Utf8>);
typedef EncryptSlateFFI = Pointer<Utf8> Function(Pointer<Utf8>,
    Pointer<Utf8>, Pointer<Int8>, Pointer<Utf8>, Pointer<Utf8>);

typedef PostSlateToNode = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef PostSlateToNodeFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);

typedef DeleteWallet = Pointer<Utf8> Function(Pointer<Utf8>);
typedef DeleteWalletFFI = Pointer<Utf8> Function(Pointer<Utf8>);

typedef OpenWallet = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);
typedef OpenWalletFFI = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>);

final WalletMnemonic _walletMnemonic = epicCashNative
    .lookup<NativeFunction<WalletMnemonicFFI>>("get_mnemonic")
    .asFunction();

String walletMnemonic() {
  return _walletMnemonic().toDartString();
}

final WalletInit _initWallet = epicCashNative
    .lookup<NativeFunction<WalletInitFFI>>("wallet_init")
    .asFunction();

String initWallet(
    String config, String mnemonic, String password, String name) {
  return _initWallet(config.toNativeUtf8(), mnemonic.toNativeUtf8(),
      password.toNativeUtf8(), name.toNativeUtf8())
      .toDartString();
}

final WalletInfo _walletInfo = epicCashNative
    .lookup<NativeFunction<WalletInfoFFI>>("rust_wallet_balances")
    .asFunction();

Future<String> getWalletInfo(String wallet,
    int refreshFromNode, int min_confirmations) async {
  return _walletInfo(
          wallet.toNativeUtf8(),
          refreshFromNode.toString().toNativeUtf8().cast<Int8>(),
          min_confirmations.toString().toNativeUtf8().cast<Int8>())
      .toDartString();
}

final RecoverWallet _recoverWallet = epicCashNative
    .lookup<NativeFunction<RecoverWalletFFI>>("rust_recover_from_mnemonic")
    .asFunction();

String recoverWallet(
    String config, String password, String mnemonic, String name) {
  return _recoverWallet(config.toNativeUtf8(), password.toNativeUtf8(),
      mnemonic.toNativeUtf8(), name.toNativeUtf8())
      .toDartString();
}

final ScanOutPuts _scanOutPuts = epicCashNative
    .lookup<NativeFunction<ScanOutPutsFFI>>("rust_wallet_scan_outputs")
    .asFunction();

Future<String> scanOutPuts(
    String wallet, int startHeight, int numberOfBlocks) async {
  return _scanOutPuts(
    wallet.toNativeUtf8(),
    startHeight.toString().toNativeUtf8().cast<Int8>(),
    numberOfBlocks.toString().toNativeUtf8().cast<Int8>(),
  ).toDartString();
}

final CreateTransaction _createTransaction = epicCashNative
    .lookup<NativeFunction<CreateTransactionFFI>>("rust_create_tx")
    .asFunction();

Future<String> createTransaction(
    String wallet,
    int amount,
    String address,
    int secretKey,
    String epicboxConfig,
    int minimumConfirmations) async {
  return _createTransaction(
    wallet.toNativeUtf8(),
    amount.toString().toNativeUtf8().cast<Int8>(),
    address.toNativeUtf8(),
    secretKey.toString().toNativeUtf8().cast<Int8>(),
    epicboxConfig.toNativeUtf8(),
    minimumConfirmations.toString().toNativeUtf8().cast<Int8>(),
  ).toDartString();
}

final GetTransactions _getTransactions = epicCashNative
    .lookup<NativeFunction<GetTransactionsFFI>>("rust_txs_get")
    .asFunction();

Future<String> getTransactions(
    String wallet, int refreshFromNode) async {
  return _getTransactions(wallet.toNativeUtf8(),
          refreshFromNode.toString().toNativeUtf8().cast<Int8>())
      .toDartString();
}

final CancelTransaction _cancelTransaction = epicCashNative
    .lookup<NativeFunction<CancelTransactionFFI>>("rust_tx_cancel")
    .asFunction();

String cancelTransaction(String wallet, String transactionId) {
  return _cancelTransaction(wallet.toNativeUtf8(),
          transactionId.toNativeUtf8())
      .toDartString();
}

final GetChainHeight _getChainHeight = epicCashNative
    .lookup<NativeFunction<GetChainHeightFFI>>("rust_get_chain_height")
    .asFunction();

int getChainHeight(String config) {
  String latestHeight = _getChainHeight(config.toNativeUtf8()).toDartString();
  return int.parse(latestHeight);
}

final AddressInfo _addressInfo = epicCashNative
    .lookup<NativeFunction<AddressInfoFFI>>("rust_get_wallet_address")
    .asFunction();

String getAddressInfo(
    String wallet, int index, String epicboxConfig) {
  return _addressInfo(
          wallet.toNativeUtf8(),
          index.toString().toNativeUtf8().cast<Int8>(),
          epicboxConfig.toNativeUtf8())
      .toDartString();
}

final ValidateAddress _validateSendAddress = epicCashNative
    .lookup<NativeFunction<ValidateAddressFFI>>("rust_validate_address")
    .asFunction();

String validateSendAddress(String address) {
  return _validateSendAddress(address.toNativeUtf8()).toDartString();
}

final PendingSlates _getPendingSlates = epicCashNative
    .lookup<NativeFunction<PendingSlatesFFI>>("rust_decrypt_unprocessed_slates")
    .asFunction();

Future<String> getPendingSlates(
    String wallet, int secretKeyIndex, String slates) async {
  return _getPendingSlates(
          wallet.toNativeUtf8(),
          secretKeyIndex.toString().toNativeUtf8().cast<Int8>(),
          slates.toNativeUtf8())
      .toDartString();
}

final SubscribeRequest _getSubscribeRequest = epicCashNative
    .lookup<NativeFunction<SubscribeRequestFFI>>("subscribe_request")
    .asFunction();

Future<String> getSubscribeRequest(String wallet,
    int secretKeyIndex, String epicboxConfig) async {
  return _getSubscribeRequest(
          wallet.toNativeUtf8(),
          secretKeyIndex.toString().toNativeUtf8().cast<Int8>(),
          epicboxConfig.toNativeUtf8())
      .toDartString();
}

final ProcessSlates _processSlates = epicCashNative
    .lookup<NativeFunction<ProcessSlatesFFI>>("rust_process_pending_slates")
    .asFunction();

Future<String> processSlates(
    String wallet, String slates) async {
  return _processSlates(
          wallet.toNativeUtf8(), slates.toNativeUtf8())
      .toDartString();
}

final TransactionFees _transactionFees = epicCashNative
    .lookup<NativeFunction<TransactionFeesFFI>>("rust_get_tx_fees")
    .asFunction();

Future<String> getTransactionFees(String wallet, int amount,
    int minimumConfirmations) async {
  return _transactionFees(
          wallet.toNativeUtf8(),
          amount.toString().toNativeUtf8().cast<Int8>(),
          minimumConfirmations.toString().toNativeUtf8().cast<Int8>())
      .toDartString();
}

final EncryptSlate _encryptSlate = epicCashNative
    .lookup<NativeFunction<EncryptSlateFFI>>("rust_encrypt_slate")
    .asFunction();

Future<String> getEncryptedSlate(String wallet, String address,
    int secretKeyIndex, String epicboxConfig, String slate) async {
  return _encryptSlate(
          wallet.toNativeUtf8(),
          address.toNativeUtf8(),
          secretKeyIndex.toString().toNativeUtf8().cast<Int8>(),
          epicboxConfig.toNativeUtf8(),
          slate.toNativeUtf8())
      .toDartString();
}

final PostSlateToNode _postSlateToNode = epicCashNative
    .lookup<NativeFunction<PostSlateToNodeFFI>>("rust_post_slate_to_node")
    .asFunction();

Future<String> postSlateToNode(String wallet, String txSlateId) async {
  return _postSlateToNode(
          wallet.toNativeUtf8(),
          txSlateId.toNativeUtf8())
      .toDartString();
}

final DeleteWallet _deleteWallet = epicCashNative
    .lookup<NativeFunction<DeleteWalletFFI>>("rust_delete_wallet")
    .asFunction();

Future<String> deleteWallet(String wallet) async {
  return _deleteWallet(
      wallet.toNativeUtf8())
      .toDartString();
}

final OpenWallet _openWallet = epicCashNative
    .lookup<NativeFunction<OpenWalletFFI>>("rust_open_wallet")
    .asFunction();

String openWallet(
    String config, String password) {
  return _openWallet(config.toNativeUtf8(),
      password.toNativeUtf8())
      .toDartString();
}


