import 'dart:convert';
import 'dart:ffi';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';

import 'epic_cash.dart' as lib_epiccash;
import 'models/transaction.dart';
import 'src/errors.dart' as epic_errors;
import 'src/ffi_worker.dart';
import 'src/parsing.dart' as parsing;

class BadEpicHttpAddressException implements Exception {
  final String? message;

  BadEpicHttpAddressException({this.message});

  @override
  String toString() {
    return "BadEpicHttpAddressException: $message";
  }
}

abstract class ListenerManager {
  static Pointer<Void>? pointer;
}

///
/// Wrapped up calls to flutter_libepiccash.
///
/// Should all be static calls (no state stored in this class)
///
abstract class LibEpiccash {
  static final Mutex m = Mutex();

  static void _checkForError(String result) {
    epic_errors.throwIfError(result);
  }

  ///
  /// Check if [address] is a valid epiccash address according to libepiccash
  ///
  static bool validateSendAddress({required String address}) {
    final String validate = lib_epiccash.validateSendAddress(address);
    // Trust the Rust-side validation result exclusively.
    return int.tryParse(validate) == 1;
  }

  ///
  /// Fetch the mnemonic For a new wallet (Only used in the example app)
  ///
  // TODO: ensure the above documentation comment is correct
  // TODO: ensure this will always return the mnemonic. If not, this function should throw an exception
  //Function is used in _getMnemonicList()
  // wrap in mutex? -> would need to be Future<String>
  static String getMnemonic() {
    try {
      final String mnemonic = lib_epiccash.walletMnemonic();
      if (mnemonic.isEmpty) {
        throw Exception("Error getting mnemonic, returned empty string");
      }
      return mnemonic;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Private function wrapper (worker isolate)
  static Future<String> _initializeWalletWrapper(
    ({
      String config,
      String mnemonic,
      String password,
      String name,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('initWallet', {
      'config': data.config,
      'mnemonic': data.mnemonic,
      'password': data.password,
      'name': data.name,
    });
  }

  ///
  /// Create a new epiccash wallet.
  ///
  // TODO: Complete/modify the documentation comment above
  // TODO: Should return a void future. On error this function should throw and exception
  static Future<String> initializeNewWallet({
    required String config,
    required String mnemonic,
    required String password,
    required String name,
  }) async {
    return await m.protect(() async {
      try {
        final result = await _initializeWalletWrapper((
          config: config,
          mnemonic: mnemonic,
          password: password,
          name: name,
        ));

        _checkForError(result);
        return epic_errors.unwrapOkData(result);
      } catch (e) {
        throw ("Error creating new wallet : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for wallet balances
  ///
  static Future<String> _walletBalancesWrapper(
    ({
      String wallet,
      int refreshFromNode,
      int minimumConfirmations,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('getWalletInfo', {
      'wallet': data.wallet,
      'refreshFromNode': data.refreshFromNode,
      'minimumConfirmations': data.minimumConfirmations,
    });
  }

  ///
  /// Get balance information for the currently open wallet
  ///
  static Future<
      ({
        double awaitingFinalization,
        double pending,
        double spendable,
        double total
      })> getWalletBalances({
    required String wallet,
    required int refreshFromNode,
    required int minimumConfirmations,
  }) async {
    return await m.protect(() async {
      try {
        final String balances = await _walletBalancesWrapper((
          wallet: wallet,
          refreshFromNode: refreshFromNode,
          minimumConfirmations: minimumConfirmations,
        ));

        //If balances is valid json return, else return error
        _checkForError(balances);
        final unwrappedBalances = epic_errors.unwrapOkData(balances);
        return parsing.parseBalances(unwrappedBalances);
      } catch (e) {
        throw ("Error getting wallet info : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for scanning output function
  ///
  static Future<String> _scanOutputsWrapper(
    ({
      String wallet,
      int startHeight,
      int numberOfBlocks,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('scanOutPuts', {
      'wallet': data.wallet,
      'startHeight': data.startHeight,
      'numberOfBlocks': data.numberOfBlocks,
    });
  }

  ///
  /// Scan Epic outputs
  ///
  static Future<int> scanOutputs({
    required String wallet,
    required int startHeight,
    required int numberOfBlocks,
  }) async {
    try {
      final result = await m.protect(() async {
        return await _scanOutputsWrapper((
          wallet: wallet,
          startHeight: startHeight,
          numberOfBlocks: numberOfBlocks,
        ));
      });
      final unwrapped = epic_errors.unwrapOkData(result);
      final response = int.tryParse(unwrapped);
      if (response == null) {
        throw Exception(result);
      }
      return response;
    } catch (e) {
      throw ("LibEpiccash.scanOutputs failed: ${e.toString()}");
    }
  }

  ///
  /// Private function wrapper for create transactions
  ///
  static Future<String> _createTransactionWrapper(
    ({
      String wallet,
      int amount,
      String address,
      int secretKeyIndex,
      String epicboxConfig,
      int minimumConfirmations,
      String note,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('createTransaction', {
      'wallet': data.wallet,
      'amount': data.amount,
      'address': data.address,
      'secretKeyIndex': data.secretKeyIndex,
      'epicboxConfig': data.epicboxConfig,
      'minimumConfirmations': data.minimumConfirmations,
      'note': data.note,
    });
  }

  ///
  /// Create an Epic transaction
  ///
  static Future<({String slateId, String commitId})> createTransaction({
    required String wallet,
    required int amount,
    required String address,
    required int secretKeyIndex,
    required String epicboxConfig,
    required int minimumConfirmations,
    required String note,
  }) async {
    return await m.protect(() async {
      try {
        final String result = await _createTransactionWrapper((
          wallet: wallet,
          amount: amount,
          address: address,
          secretKeyIndex: secretKeyIndex,
          epicboxConfig: epicboxConfig,
          minimumConfirmations: minimumConfirmations,
          note: note,
        ));

        _checkForError(result);
        final unwrapped = epic_errors.unwrapOkData(result);
        return parsing.parseCreateTxResult(unwrapped);
      } catch (e) {
        throw ("Error creating epic transaction : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function wrapper for get transactions
  ///
  static Future<String> _getTransactionsWrapper(
    ({
      String wallet,
      int refreshFromNode,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('getTransactions', {
      'wallet': data.wallet,
      'refreshFromNode': data.refreshFromNode,
    });
  }

  ///
  ///
  ///
  static Future<List<Transaction>> getTransactions({
    required String wallet,
    required int refreshFromNode,
  }) async {
    return await m.protect(() async {
      try {
        final result = await _getTransactionsWrapper((
          wallet: wallet,
          refreshFromNode: refreshFromNode,
        ));

        _checkForError(result);
        final unwrappedResult = epic_errors.unwrapOkData(result);
        final List<Transaction> finalResult = [];
        final jsonResult = parsing.parseTransactionsRawList(unwrappedResult);
        for (final tx in jsonResult) {
          finalResult.add(Transaction.fromJson(tx));
        }
        return finalResult;
      } catch (e) {
        throw ("Error getting epic transactions : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for cancel transaction function
  ///
  static Future<String> _cancelTransactionWrapper(
    ({
      String wallet,
      String transactionId,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('cancelTransaction', {
      'wallet': data.wallet,
      'transactionId': data.transactionId,
    });
  }

  ///
  /// Cancel current Epic transaction
  ///
  /// returns an empty String on success, error message on failure
  static Future<String> cancelTransaction({
    required String wallet,
    required String transactionId,
  }) async {
    return await m.protect(() async {
      try {
        final result = await _cancelTransactionWrapper((
          wallet: wallet,
          transactionId: transactionId,
        ));

        _checkForError(result);
        return epic_errors.unwrapOkData(result);
      } catch (e) {
        throw ("Error canceling epic transaction : ${e.toString()}");
      }
    });
  }

  static Future<int> _chainHeightWrapper(
    ({
      String config,
    }) data,
  ) async {
    return await FfiWorker.instance.call<int>('getChainHeight', {
      'config': data.config,
    });
  }

  static Future<int> getChainHeight({
    required String config,
  }) async {
    return await m.protect(() async {
      try {
        return await _chainHeightWrapper((config: config,));
      } catch (e) {
        throw ("Error getting chain height : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for address info function
  ///
  static Future<String> _addressInfoWrapper(
    ({
      String wallet,
      int index,
      String epicboxConfig,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('getAddressInfo', {
      'wallet': data.wallet,
      'index': data.index,
      'epicboxConfig': data.epicboxConfig,
    });
  }

  ///
  /// get Epic address info
  ///
  static Future<String> getAddressInfo({
    required String wallet,
    required int index,
    required String epicboxConfig,
  }) async {
    return await m.protect(() async {
      try {
        final result = await _addressInfoWrapper((
          wallet: wallet,
          index: index,
          epicboxConfig: epicboxConfig,
        ));

        _checkForError(result);

        return result;
      } catch (e) {
        throw ("Error getting address info : ${e.toString()}");
      }
    });
  }

  ///
  /// Private function for getting transaction fees
  ///
  static Future<String> _transactionFeesWrapper(
    ({
      String wallet,
      int amount,
      int minimumConfirmations,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('getTransactionFees', {
      'wallet': data.wallet,
      'amount': data.amount,
      'minimumConfirmations': data.minimumConfirmations,
    });
  }

  ///
  /// get transaction fees for Epic
  ///
  static Future<
      ({
        int fee,
        bool strategyUseAll,
        int total,
      })> getTransactionFees({
    required String wallet,
    required int amount,
    required int minimumConfirmations,
    required int available,
  }) async {
    return await m.protect(() async {
      try {
        String fees = await _transactionFeesWrapper((
          wallet: wallet,
          amount: amount,
          minimumConfirmations: minimumConfirmations,
        ));

        if (available == amount) {
          if (fees.contains("Required")) {
            final splits = fees.split(" ");
            Decimal required = Decimal.zero;
            Decimal available = Decimal.zero;
            for (int i = 0; i < splits.length; i++) {
              final word = splits[i];
              if (word == "Required:") {
                required = Decimal.parse(splits[i + 1].replaceAll(",", ""));
              } else if (word == "Available:") {
                available = Decimal.parse(splits[i + 1].replaceAll(",", ""));
              }
            }
            final int largestSatoshiFee =
                ((required - available) * Decimal.fromInt(100000000))
                    .toBigInt()
                    .toInt();
            final amountSending = amount - largestSatoshiFee;
            //Get fees for this new amount
            fees = await _transactionFeesWrapper((
              wallet: wallet,
              amount: amountSending,
              minimumConfirmations: minimumConfirmations,
            ));
          }
        }

        _checkForError(fees);
        final unwrapped = epic_errors.unwrapOkData(fees);
        return parsing.parseTxFees(unwrapped);
      } catch (e) {
        throw (e.toString());
      }
    });
  }

  ///
  /// Private function wrapper for recover wallet function
  ///
  static Future<String> _recoverWalletWrapper(
    ({
      String config,
      String password,
      String mnemonic,
      String name,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('recoverWallet', {
      'config': data.config,
      'password': data.password,
      'mnemonic': data.mnemonic,
      'name': data.name,
    });
  }

  ///
  /// Recover an Epic wallet using a mnemonic
  ///
  static Future<void> recoverWallet({
    required String config,
    required String password,
    required String mnemonic,
    required String name,
  }) async {
    try {
      final result = await _recoverWalletWrapper((
        config: config,
        password: password,
        mnemonic: mnemonic,
        name: name,
      ));
      _checkForError(result);
    } catch (e) {
      throw (e.toString());
    }
  }

  ///
  /// Private function wrapper for delete wallet function
  ///
  static Future<String> _deleteWalletWrapper(
    ({
      String wallet,
      String config,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('deleteWallet', {
      'wallet': data.wallet,
      'config': data.config,
    });
  }

  ///
  /// Delete an Epic wallet
  ///
  static Future<String> deleteWallet({
    required String wallet,
    required String config,
  }) async {
    try {
      final result = await _deleteWalletWrapper((
        wallet: wallet,
        config: config,
      ));

      _checkForError(result);
      return epic_errors.unwrapOkData(result);
    } catch (e) {
      throw ("Error deleting wallet : ${e.toString()}");
    }
  }

  ///
  /// Private function wrapper for open wallet function
  ///
  static Future<String> _openWalletWrapper(
    ({
      String config,
      String password,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('openWallet', {
      'config': data.config,
      'password': data.password,
    });
  }

  ///
  /// Open an Epic wallet
  ///
  static Future<String> openWallet({
    required String config,
    required String password,
  }) async {
    try {
      final result = await _openWalletWrapper((
        config: config,
        password: password,
      ));

      _checkForError(result);
      return epic_errors.unwrapOkData(result);
    } catch (e) {
      throw ("Error opening wallet : ${e.toString()}");
    }
  }

  ///
  /// Private function for txHttpSend function
  ///
  static Future<String> _txHttpSendWrapper(
    ({
      String wallet,
      int selectionStrategyIsAll,
      int minimumConfirmations,
      String message,
      int amount,
      String address,
    }) data,
  ) async {
    return await FfiWorker.instance.call<String>('txHttpSend', {
      'wallet': data.wallet,
      'selectionStrategyIsAll': data.selectionStrategyIsAll,
      'minimumConfirmations': data.minimumConfirmations,
      'message': data.message,
      'amount': data.amount,
      'address': data.address,
    });
  }

  ///
  ///
  ///
  static Future<({String commitId, String slateId})> txHttpSend({
    required String wallet,
    required int selectionStrategyIsAll,
    required int minimumConfirmations,
    required String message,
    required int amount,
    required String address,
  }) async {
    try {
      final result = await _txHttpSendWrapper((
        wallet: wallet,
        selectionStrategyIsAll: selectionStrategyIsAll,
        minimumConfirmations: minimumConfirmations,
        message: message,
        amount: amount,
        address: address,
      ));
      _checkForError(result);
      final unwrapped = epic_errors.unwrapOkData(result);
      return parsing.parseCreateTxResult(unwrapped);
    } catch (e) {
      throw ("Error sending tx HTTP : ${e.toString()}");
    }
  }

  static void startEpicboxListener({
    required String wallet,
    required String epicboxConfig,
  }) {
    try {
      ListenerManager.pointer =
          lib_epiccash.epicboxListenerStart(wallet, epicboxConfig);
    } catch (e) {
      throw ("Error starting wallet listener ${e.toString()}");
    }
  }

  static void stopEpicboxListener() {
    if (ListenerManager.pointer != null) {
      lib_epiccash.epicboxListenerStop(ListenerManager.pointer!);
    }
  }
}
