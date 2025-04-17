import 'dart:convert';
import 'dart:ffi';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:mutex/mutex.dart';

import 'epic_cash.dart' as lib_epiccash;
import 'models/transaction.dart';

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
    if (result.startsWith("Error ")) {
      throw Exception(result);
    }
  }

  ///
  /// Check if [address] is a valid epiccash address according to libepiccash
  ///
  static bool validateSendAddress({required String address}) {
    final String validate = lib_epiccash.validateSendAddress(address);
    if (int.parse(validate) == 1) {
      // Check if address contains a domain
      if (address.contains("@")) {
        return true;
      }
      return false;
    } else {
      return false;
    }
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

  // Private function wrapper for compute
  static Future<String> _initializeWalletWrapper(
    ({
      String config,
      String mnemonic,
      String password,
      String name,
    }) data,
  ) async {
    final String initWalletStr = lib_epiccash.initWallet(
      data.config,
      data.mnemonic,
      data.password,
      data.name,
    );
    return initWalletStr;
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
        final result = await compute(
          _initializeWalletWrapper,
          (
            config: config,
            mnemonic: mnemonic,
            password: password,
            name: name,
          ),
        );

        _checkForError(result);

        return result;
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
    return lib_epiccash.getWalletInfo(
      data.wallet,
      data.refreshFromNode,
      data.minimumConfirmations,
    );
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
        final String balances = await compute(
          _walletBalancesWrapper,
          (
            wallet: wallet,
            refreshFromNode: refreshFromNode,
            minimumConfirmations: minimumConfirmations,
          ),
        );

        //If balances is valid json return, else return error
        if (balances.toUpperCase().contains("ERROR")) {
          throw Exception(balances);
        }
        final jsonBalances = json.decode(balances);
        //Return balances as record
        final ({
          double spendable,
          double pending,
          double total,
          double awaitingFinalization
        }) balancesRecord = (
          spendable: jsonBalances['amount_currently_spendable'],
          pending: jsonBalances['amount_awaiting_finalization'],
          total: jsonBalances['total'],
          awaitingFinalization: jsonBalances['amount_awaiting_finalization'],
        );
        return balancesRecord;
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
    return lib_epiccash.scanOutPuts(
      data.wallet,
      data.startHeight,
      data.numberOfBlocks,
    );
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
        return await compute(
          _scanOutputsWrapper,
          (
            wallet: wallet,
            startHeight: startHeight,
            numberOfBlocks: numberOfBlocks,
          ),
        );
      });
      final response = int.tryParse(result);
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
      bool returnSlate,
    }) data,
  ) async {
    return lib_epiccash.createTransaction(
      data.wallet,
      data.amount,
      data.address,
      data.secretKeyIndex,
      data.epicboxConfig,
      data.minimumConfirmations,
      data.note,
      returnSlate: data.returnSlate,
    );
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
    bool returnSlate = false,
  }) async {
    return await m.protect(() async {
      try {
        final String result = await compute(
          _createTransactionWrapper,
          (
            wallet: wallet,
            amount: amount,
            address: address,
            secretKeyIndex: secretKeyIndex,
            epicboxConfig: epicboxConfig,
            minimumConfirmations: minimumConfirmations,
            note: note,
            returnSlate: returnSlate,
          ),
        );

        if (result.toUpperCase().contains("ERROR")) {
          throw Exception("Error creating transaction ${result.toString()}");
        }

        //Decode sent tx and return Slate Id
        final slate0 = jsonDecode(result);
        final slate = jsonDecode(slate0[0] as String);
        final part1 = jsonDecode(slate[0] as String);
        final part2 = jsonDecode(slate[1] as String);

        final List<dynamic> outputs = part2['tx']?['body']?['outputs'] as List;
        final commitId =
            (outputs.isEmpty) ? '' : outputs[0]['commit'] as String;

        final ({String slateId, String commitId}) data = (
          slateId: part1[0]['tx_slate_id'],
          commitId: commitId,
        );

        return data;
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
    return lib_epiccash.getTransactions(
      data.wallet,
      data.refreshFromNode,
    );
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
        final result = await compute(
          _getTransactionsWrapper,
          (
            wallet: wallet,
            refreshFromNode: refreshFromNode,
          ),
        );

        if (result.toUpperCase().contains("ERROR")) {
          throw Exception(
            "Error getting epic transactions ${result.toString()}",
          );
        }

//Parse the returned data as an EpicTransaction
        final List<Transaction> finalResult = [];
        final jsonResult = json.decode(result) as List;

        for (final tx in jsonResult) {
          final Transaction itemTx = Transaction.fromJson(tx);
          finalResult.add(itemTx);
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
    return lib_epiccash.cancelTransaction(
      data.wallet,
      data.transactionId,
    );
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
        final result = await compute(
          _cancelTransactionWrapper,
          (
            wallet: wallet,
            transactionId: transactionId,
          ),
        );

        _checkForError(result);

        return result;
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
    return lib_epiccash.getChainHeight(data.config);
  }

  static Future<int> getChainHeight({
    required String config,
  }) async {
    return await m.protect(() async {
      try {
        return await compute(_chainHeightWrapper, (config: config,));
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
    return lib_epiccash.getAddressInfo(
      data.wallet,
      data.index,
      data.epicboxConfig,
    );
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
        final result = await compute(
          _addressInfoWrapper,
          (
            wallet: wallet,
            index: index,
            epicboxConfig: epicboxConfig,
          ),
        );

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
    return lib_epiccash.getTransactionFees(
      data.wallet,
      data.amount,
      data.minimumConfirmations,
    );
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
        String fees = await compute(
          _transactionFeesWrapper,
          (
            wallet: wallet,
            amount: amount,
            minimumConfirmations: minimumConfirmations,
          ),
        );

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
            fees = await compute(
              _transactionFeesWrapper,
              (
                wallet: wallet,
                amount: amountSending,
                minimumConfirmations: minimumConfirmations,
              ),
            );
          }
        }

        if (fees.toUpperCase().contains("ERROR")) {
          //Check if the error is an
          //Throw the returned error
          throw Exception(fees);
        }
        final decodedFees = json.decode(fees);
        final feeItem = decodedFees[0];
        final ({
          bool strategyUseAll,
          int total,
          int fee,
        }) feeRecord = (
          strategyUseAll: feeItem['selection_strategy_is_use_all'],
          total: feeItem['total'],
          fee: feeItem['fee'],
        );
        return feeRecord;
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
    return lib_epiccash.recoverWallet(
      data.config,
      data.password,
      data.mnemonic,
      data.name,
    );
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
      await compute(
        _recoverWalletWrapper,
        (
          config: config,
          password: password,
          mnemonic: mnemonic,
          name: name,
        ),
      );
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
    return lib_epiccash.deleteWallet(
      data.wallet,
      data.config,
    );
  }

  ///
  /// Delete an Epic wallet
  ///
  static Future<String> deleteWallet({
    required String wallet,
    required String config,
  }) async {
    try {
      final result = await compute(
        _deleteWalletWrapper,
        (
          wallet: wallet,
          config: config,
        ),
      );

      _checkForError(result);

      return result;
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
    return lib_epiccash.openWallet(
      data.config,
      data.password,
    );
  }

  ///
  /// Open an Epic wallet
  ///
  static Future<String> openWallet({
    required String config,
    required String password,
  }) async {
    try {
      final result = await compute(
        _openWalletWrapper,
        (
          config: config,
          password: password,
        ),
      );

      _checkForError(result);

      return result;
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
    return lib_epiccash.txHttpSend(
      data.wallet,
      data.selectionStrategyIsAll,
      data.minimumConfirmations,
      data.message,
      data.amount,
      data.address,
    );
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
      final result = await compute(
        _txHttpSendWrapper,
        (
          wallet: wallet,
          selectionStrategyIsAll: selectionStrategyIsAll,
          minimumConfirmations: minimumConfirmations,
          message: message,
          amount: amount,
          address: address,
        ),
      );
      if (result.toUpperCase().contains("ERROR")) {
        throw Exception("Error creating transaction ${result.toString()}");
      }

      //Decode sent tx and return Slate Id
      final slate0 = jsonDecode(result);
      final slate = jsonDecode(slate0[0] as String);
      final part1 = jsonDecode(slate[0] as String);
      final part2 = jsonDecode(slate[1] as String);

      final ({String slateId, String commitId}) data = (
        slateId: part1[0]['tx_slate_id'],
        commitId: part2['tx']['body']['outputs'][0]['commit'],
      );

      return data;
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
