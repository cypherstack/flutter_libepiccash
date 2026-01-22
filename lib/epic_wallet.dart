import 'dart:convert';
import 'dart:isolate';

import 'package:decimal/decimal.dart';

import 'epic_cash.dart' as epic_ffi;
import 'models/balance_data.dart';
import 'models/slate_response.dart';
import 'models/transaction.dart';
import 'utils/epic_errors.dart';
import 'utils/validation_helpers.dart';

class EpicWallet {
  String? _walletHandle;
  final String _config;
  bool _isClosing = false;

  EpicWallet._(this._walletHandle, this._config);

  String _getWalletHandle() {
    if (_walletHandle == null) {
      throw EpicWalletClosedException();
    }
    return _walletHandle!;
  }

  bool isClosed() => _walletHandle == null;

  static Future<EpicWallet> create({
    required String config,
    required String mnemonic,
    required String password,
    required String name,
  }) async {
    try {
      final result = await Isolate.run(() {
        return epic_ffi.initWallet(config, mnemonic, password, name);
      });

      checkForError(result);

      final walletHandle = await Isolate.run(() {
        return epic_ffi.openWallet(config, password);
      });

      checkForError(walletHandle);

      return EpicWallet._(walletHandle, config);
    } catch (e, s) {
      if (e is EpicWalletException) {
        rethrow;
      }
      throw EpicWalletCreationException(
        'Failed to create wallet: $e',
        stackTrace: s,
      );
    }
  }

  static Future<EpicWallet> load({
    required String config,
    required String password,
  }) async {
    try {
      final walletHandle = await Isolate.run(() {
        return epic_ffi.openWallet(config, password);
      });

      checkForError(walletHandle);

      return EpicWallet._(walletHandle, config);
    } catch (e, s) {
      if (e is EpicWalletException) {
        rethrow;
      }
      throw EpicWalletCreationException(
        'Failed to load wallet: $e',
        stackTrace: s,
      );
    }
  }

  static Future<EpicWallet> recover({
    required String config,
    required String password,
    required String mnemonic,
    required String name,
  }) async {
    try {
      final result = await Isolate.run(() {
        return epic_ffi.recoverWallet(config, password, mnemonic, name);
      });

      checkForError(result);

      final walletHandle = await Isolate.run(() {
        return epic_ffi.openWallet(config, password);
      });

      checkForError(walletHandle);

      return EpicWallet._(walletHandle, config);
    } catch (e, s) {
      if (e is EpicWalletException) {
        rethrow;
      }
      throw EpicWalletCreationException(
        'Failed to recover wallet: $e',
        stackTrace: s,
      );
    }
  }

  Future<BalanceData> getBalances({
    int refreshFromNode = 1,
    int minimumConfirmations = 10,
  }) async {
    final handle = _getWalletHandle();

    final balancesJson = await Isolate.run(() {
      return epic_ffi.getWalletInfo(
        handle,
        refreshFromNode,
        minimumConfirmations,
      );
    });

    checkForError(balancesJson);

    return BalanceData.fromJson(balancesJson);
  }

  Future<({
    double spendable,
    double pending,
    double total,
    double awaitingFinalization,
  })> getBalancesRecord({
    int refreshFromNode = 1,
    int minimumConfirmations = 10,
  }) async {
    final balances = await getBalances(
      refreshFromNode: refreshFromNode,
      minimumConfirmations: minimumConfirmations,
    );
    return balances.toRecord();
  }

  Future<int> scanOutputs({
    required int startHeight,
    required int numberOfBlocks,
  }) async {
    final handle = _getWalletHandle();

    final result = await Isolate.run(() {
      return epic_ffi.scanOutPuts(handle, startHeight, numberOfBlocks);
    });

    checkForError(result);

    return int.parse(result);
  }

  Future<List<Transaction>> getTransactions({
    int refreshFromNode = 1,
  }) async {
    final handle = _getWalletHandle();

    final txListJson = await Isolate.run(() {
      return epic_ffi.getTransactions(handle, refreshFromNode);
    });

    checkForError(txListJson);

    final txList = jsonDecode(txListJson) as List<dynamic>;
    return txList.map((tx) => Transaction.fromJson(tx)).toList();
  }

  Future<String> getAddressInfo({
    int index = 0,
    required String epicboxConfig,
  }) async {
    final handle = _getWalletHandle();

    final address = await Isolate.run(() {
      return epic_ffi.getAddressInfo(handle, index, epicboxConfig);
    });

    checkForError(address);

    return address;
  }

  Future<SlateResponse> createTransaction({
    required int amount,
    required String address,
    int secretKeyIndex = 0,
    required String epicboxConfig,
    int minimumConfirmations = 10,
    String note = "",
    bool returnSlate = false,
  }) async {
    final handle = _getWalletHandle();

    final result = await Isolate.run(() {
      return epic_ffi.createTransaction(
        handle,
        amount,
        address,
        secretKeyIndex,
        epicboxConfig,
        minimumConfirmations,
        note,
        returnSlate: returnSlate,
      );
    });

    checkForError(result);

    return SlateResponse.fromResult(result);
  }

  Future<({
    String slateId,
    String commitId,
    String slateJson,
  })> createTransactionRecord({
    required int amount,
    required String address,
    int secretKeyIndex = 0,
    required String epicboxConfig,
    int minimumConfirmations = 10,
    String note = "",
  }) async {
    final slate = await createTransaction(
      amount: amount,
      address: address,
      secretKeyIndex: secretKeyIndex,
      epicboxConfig: epicboxConfig,
      minimumConfirmations: minimumConfirmations,
      note: note,
    );
    return slate.toRecord();
  }

  Future<String> cancelTransaction({
    required String transactionId,
  }) async {
    final handle = _getWalletHandle();

    final result = await Isolate.run(() {
      return epic_ffi.cancelTransaction(handle, transactionId);
    });

    checkForError(result);

    return result;
  }

  Future<({int fee, bool strategyUseAll, int total})> getTransactionFees({
    required int amount,
    required int minimumConfirmations,
  }) async {
    final handle = _getWalletHandle();

    final balancesJson = await Isolate.run(() {
      return epic_ffi.getWalletInfo(handle, 1, minimumConfirmations);
    });

    checkForError(balancesJson);

    final jsonBalances = parseJsonObject(balancesJson, 'transaction fees');
    final available = _parseAmount(
      jsonBalances['amount_currently_spendable'],
      'amount_currently_spendable',
    );

    if (available == 0 || amount > available) {
      final required = Decimal.parse(amount.toString());
      final availableDecimal = Decimal.parse(available.toString());

      final largestSatoshiFee = ((required - availableDecimal) *
              Decimal.fromInt(100000000))
          .toBigInt();

      final safeFee = bigIntToSafeInt(largestSatoshiFee, 'transaction fee');

      return (fee: safeFee, strategyUseAll: false, total: amount);
    }

    final feesJson = await Isolate.run(() {
      return epic_ffi.getTransactionFees(handle, amount, minimumConfirmations);
    });

    checkForError(feesJson);

    final fees = parseJsonObject(feesJson, 'transaction fees');

    return (
      fee: parseInt(fees['fee'], 'fee'),
      strategyUseAll: parseBool(fees['amount'] == available, 'strategyUseAll'),
      total: parseInt(fees['amount'], 'amount'),
    );
  }

  Future<({String slateId, String commitId})> txHttpSend({
    required int selectionStrategyIsAll,
    required int minimumConfirmations,
    required String message,
    required int amount,
    required String address,
  }) async {
    final handle = _getWalletHandle();

    final result = await Isolate.run(() {
      return epic_ffi.txHttpSend(
        handle,
        selectionStrategyIsAll,
        minimumConfirmations,
        message,
        amount,
        address,
      );
    });

    checkForError(result);

    final slate = SlateResponse.fromResult(result);

    return (slateId: slate.slateId, commitId: slate.commitId);
  }

  Future<SlateResponse> txReceive({
    required String slateJson,
  }) async {
    final handle = _getWalletHandle();

    final result = await Isolate.run(() {
      return epic_ffi.txReceive(handle, slateJson);
    });

    checkForError(result);

    return SlateResponse.fromResult(result);
  }

  Future<({
    String slateId,
    String commitId,
    String slateJson,
  })> txReceiveRecord({
    required String slateJson,
  }) async {
    final slate = await txReceive(slateJson: slateJson);
    return slate.toRecord();
  }

  Future<SlateResponse> txFinalize({
    required String slateJson,
  }) async {
    final handle = _getWalletHandle();

    final result = await Isolate.run(() {
      return epic_ffi.txFinalize(handle, slateJson);
    });

    checkForError(result);

    return SlateResponse.fromResult(result);
  }

  Future<({String slateId, String commitId})> txFinalizeRecord({
    required String slateJson,
  }) async {
    final slate = await txFinalize(slateJson: slateJson);
    return (slateId: slate.slateId, commitId: slate.commitId);
  }

  Future<int> getChainHeight() async {
    return await Isolate.run(() {
      return epic_ffi.getChainHeight(_config);
    });
  }


  String get handle => _getWalletHandle();

  Future<void> close({bool save = false}) async {
    if (_walletHandle == null || _isClosing) return;
    _isClosing = true;

    try {
      final handle = _walletHandle!;
      _walletHandle = null;

      // Note: Epic FFI may not have a closeWallet function
      // If it does, uncomment and use:
      // await Isolate.run(() {
      //   epic_ffi.closeWallet(handle, save);
      // });
    } finally {
      _isClosing = false;
    }
  }

  void dispose() {
    close();
  }


  static double _parseAmount(dynamic value, String fieldName) {
    if (value == null) {
      throw FormatException('Missing required field: $fieldName');
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed == null) {
        throw FormatException(
          'Invalid number format for $fieldName: "$value"',
        );
      }
      return parsed;
    }

    throw FormatException(
      'Invalid type for $fieldName: expected num or String, got ${value.runtimeType}',
    );
  }
}
