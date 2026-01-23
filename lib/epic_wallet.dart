import 'dart:convert';

import 'package:decimal/decimal.dart';

import 'models/balance_data.dart';
import 'models/slate_response.dart';
import 'models/transaction.dart';
import 'src/epic_task.dart';
import 'src/epic_worker.dart';
import 'utils/epic_errors.dart';
import 'utils/validation_helpers.dart';

/// Epic wallet instance with persistent worker isolate
///
/// Each wallet instance owns a dedicated worker isolate where all operations
/// are executed. This ensures SQLite connection thread safety and should
/// prevent isolate-related crashes.
class EpicWallet {
  EpicWallet._({
    required String walletHandle,
    required EpicWorker worker,
    required String config,
    required String epicboxConfig,
  })  : _walletHandle = walletHandle,
        _worker = worker,
        _config = config,
        _epicboxConfig = epicboxConfig;

  final EpicWorker _worker;
  final String _config;
  String _epicboxConfig;

  String? _walletHandle;
  int? _listenerPointerAddress;
  bool _isClosing = false;

  String _getWalletHandle() {
    if (_walletHandle == null) {
      throw EpicWalletClosedException();
    }
    return _walletHandle!;
  }

  bool isClosed() => _walletHandle == null;

  Future<void> startListeners() async {
    await stopListeners();

    _listenerPointerAddress = await _worker.runTask<int>(
      EpicTask(
        func: EpicFuncName.startEpicboxListener,
        args: {
          "wallet": _getWalletHandle(),
          "epicboxConfig": _epicboxConfig,
        },
      ),
    );
  }

  Future<void> stopListeners() async {
    if (_listenerPointerAddress != null) {
      await _worker.runTask<bool>(
        EpicTask(
          func: EpicFuncName.stopEpicboxListener,
          args: {
            "pointer": _listenerPointerAddress!,
          },
        ),
      );
      _listenerPointerAddress = null;
    }
  }

  Future<bool> isEpicboxListenerRunning() async {
    if (_listenerPointerAddress == null) {
      return false;
    }

    final isRunning = await _worker.runTask<bool>(
      EpicTask(
        func: EpicFuncName.isEpicboxListenerRunning,
        args: {
          "pointer": _listenerPointerAddress!,
        },
      ),
    );
    if (!isRunning) {
      _listenerPointerAddress = null;
    }
    return isRunning;
  }

  static Future<EpicWallet> create({
    required String config,
    required String mnemonic,
    required String password,
    required String name,
    required String epicboxConfig,
  }) async {
    try {
      final worker = await EpicWorker.spawn();

      final initResult = await worker.runTask<String>(
        EpicTask(
          func: EpicFuncName.initWallet,
          args: {
            "config": config,
            "mnemonic": mnemonic,
            "password": password,
            "name": name,
          },
        ),
      );

      checkForError(initResult);

      final walletHandle = await worker.runTask<String>(
        EpicTask(
          func: EpicFuncName.openWallet,
          args: {
            "config": config,
            "password": password,
          },
        ),
      );

      checkForError(walletHandle);

      return EpicWallet._(
        walletHandle: walletHandle,
        worker: worker,
        config: config,
        epicboxConfig: epicboxConfig,
      );
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
    required String epicboxConfig,
  }) async {
    try {
      final worker = await EpicWorker.spawn();

      final walletHandle = await worker.runTask<String>(
        EpicTask(
          func: EpicFuncName.openWallet,
          args: {
            "config": config,
            "password": password,
          },
        ),
      );

      checkForError(walletHandle);

      return EpicWallet._(
        walletHandle: walletHandle,
        worker: worker,
        config: config,
        epicboxConfig: epicboxConfig,
      );
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
    required String epicboxConfig,
  }) async {
    try {
      final worker = await EpicWorker.spawn();

      final recoverResult = await worker.runTask<String>(
        EpicTask(
          func: EpicFuncName.recoverWallet,
          args: {
            "config": config,
            "password": password,
            "mnemonic": mnemonic,
            "name": name,
          },
        ),
      );

      checkForError(recoverResult);

      // Open wallet
      final walletHandle = await worker.runTask<String>(
        EpicTask(
          func: EpicFuncName.openWallet,
          args: {
            "config": config,
            "password": password,
          },
        ),
      );

      checkForError(walletHandle);

      return EpicWallet._(
        walletHandle: walletHandle,
        worker: worker,
        config: config,
        epicboxConfig: epicboxConfig,
      );
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

  static Future<String> getMnemonic() async {
    final worker = await EpicWorker.spawn();
    try {
      return await worker.runTask<String>(
        EpicTask(func: EpicFuncName.getMnemonic),
      );
    } finally {
      worker.dispose();
    }
  }

  static Future<bool> validateSendAddress({required String address}) async {
    final worker = await EpicWorker.spawn();
    try {
      final result = await worker.runTask<int>(
        EpicTask(
          func: EpicFuncName.validateSendAddress,
          args: {"address": address},
        ),
      );

      if (result == 1) {
        return address.contains("@");
      }
      return false;
    } finally {
      worker.dispose();
    }
  }

  static Future<int> getChainHeightForConfig({required String config}) async {
    final worker = await EpicWorker.spawn();
    try {
      return await worker.runTask<int>(
        EpicTask(
          func: EpicFuncName.getChainHeight,
          args: {
            "config": config,
          },
        ),
      );
    } finally {
      worker.dispose();
    }
  }

  Future<BalanceData> getBalances({
    int refreshFromNode = 1,
    int minimumConfirmations = 10,
  }) async {
    final balancesJson = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.getWalletInfo,
        args: {
          "wallet": _getWalletHandle(),
          "refreshFromNode": refreshFromNode,
          "minimumConfirmations": minimumConfirmations,
        },
      ),
    );

    checkForError(balancesJson);

    return BalanceData.fromJson(balancesJson);
  }

  Future<
      ({
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
    final result = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.scanOutputs,
        args: {
          "wallet": _getWalletHandle(),
          "startHeight": startHeight,
          "numberOfBlocks": numberOfBlocks,
        },
      ),
    );

    checkForError(result);

    return int.parse(result);
  }

  Future<List<Transaction>> getTransactions({
    int refreshFromNode = 1,
  }) async {
    final txListJson = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.getTransactions,
        args: {
          "wallet": _getWalletHandle(),
          "refreshFromNode": refreshFromNode,
        },
      ),
    );

    checkForError(txListJson);

    final txList = jsonDecode(txListJson) as List<dynamic>;
    return txList.map((tx) => Transaction.fromJson(tx)).toList();
  }

  Future<String> getAddressInfo({
    int index = 0,
  }) async {
    final address = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.getAddressInfo,
        args: {
          "wallet": _getWalletHandle(),
          "index": index,
          "epicboxConfig": _epicboxConfig,
        },
      ),
    );

    checkForError(address);

    return address;
  }

  Future<SlateResponse> createTransaction({
    required int amount,
    required String address,
    int secretKeyIndex = 0,
    int minimumConfirmations = 10,
    String note = "",
    bool returnSlate = false,
  }) async {
    final result = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.createTransaction,
        args: {
          "wallet": _getWalletHandle(),
          "amount": amount,
          "address": address,
          "secretKeyIndex": secretKeyIndex,
          "epicboxConfig": _epicboxConfig,
          "minimumConfirmations": minimumConfirmations,
          "note": note,
          "returnSlate": returnSlate,
        },
      ),
    );

    checkForError(result);

    return SlateResponse.fromResult(result);
  }

  Future<
      ({
        String slateId,
        String commitId,
        String slateJson,
      })> createTransactionRecord({
    required int amount,
    required String address,
    int secretKeyIndex = 0,
    int minimumConfirmations = 10,
    String note = "",
  }) async {
    final slate = await createTransaction(
      amount: amount,
      address: address,
      secretKeyIndex: secretKeyIndex,
      minimumConfirmations: minimumConfirmations,
      note: note,
    );
    return slate.toRecord();
  }

  Future<String> cancelTransaction({
    required String transactionId,
  }) async {
    final result = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.cancelTransaction,
        args: {
          "wallet": _getWalletHandle(),
          "transactionId": transactionId,
        },
      ),
    );

    checkForError(result);

    return result;
  }

  Future<({int fee, bool strategyUseAll, int total})> getTransactionFees({
    required int amount,
    required int minimumConfirmations,
  }) async {
    // Get available balance
    final balancesJson = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.getWalletInfo,
        args: {
          "wallet": _getWalletHandle(),
          "refreshFromNode": 1,
          "minimumConfirmations": minimumConfirmations,
        },
      ),
    );

    checkForError(balancesJson);

    final jsonBalances = parseJsonObject(balancesJson, 'transaction fees');
    final availableEpic = _parseAmount(
      jsonBalances['amount_currently_spendable'],
      'amount_currently_spendable',
    );

    // Convert to sats
    final available = (availableEpic * 100000000).toInt();

    if (available == 0 || amount > available) {
      final required = Decimal.parse(amount.toString());
      final availableDecimal = Decimal.parse(available.toString());

      final largestSatoshiFee =
          ((required - availableDecimal) * Decimal.fromInt(100000000))
              .toBigInt();

      final safeFee = bigIntToSafeInt(largestSatoshiFee, 'transaction fee');

      return (fee: safeFee, strategyUseAll: false, total: amount);
    }

    // Get actual fees
    final feesJson = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.getTransactionFees,
        args: {
          "wallet": _getWalletHandle(),
          "amount": amount,
          "minimumConfirmations": minimumConfirmations,
        },
      ),
    );

    checkForError(feesJson);

    final feesArray = jsonDecode(feesJson);
    if (feesArray is! List || feesArray.isEmpty) {
      throw FormatException(
          'Expected array from getTransactionFees, got ${feesArray.runtimeType}');
    }

    final fees = feesArray[0] as Map<String, dynamic>;

    return (
      fee: parseInt(fees['fee'], 'fee'),
      strategyUseAll: parseBool(
          fees['selection_strategy_is_use_all'] == true, 'strategyUseAll'),
      total: parseInt(fees['total'], 'total'),
    );
  }

  Future<({String slateId, String commitId})> txHttpSend({
    required int selectionStrategyIsAll,
    required int minimumConfirmations,
    required String message,
    required int amount,
    required String address,
  }) async {
    final result = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.txHttpSend,
        args: {
          "wallet": _getWalletHandle(),
          "selectionStrategyIsAll": selectionStrategyIsAll,
          "minimumConfirmations": minimumConfirmations,
          "message": message,
          "amount": amount,
          "address": address,
        },
      ),
    );

    checkForError(result);

    final slate = SlateResponse.fromResult(result);

    return (slateId: slate.slateId, commitId: slate.commitId);
  }

  Future<SlateResponse> txReceive({
    required String slateJson,
  }) async {
    final result = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.txReceive,
        args: {
          "wallet": _getWalletHandle(),
          "slateJson": slateJson,
        },
      ),
    );

    checkForError(result);

    return SlateResponse.fromReceiveResult(result);
  }

  Future<
      ({
        String slateId,
        String commitId,
        String slateJson,
      })> txReceiveRecord({
    required String slateJson,
  }) async {
    final slate = await txReceive(slateJson: slateJson);
    return slate.toRecord();
  }

  /// Finalize a slate
  Future<SlateResponse> txFinalize({
    required String slateJson,
  }) async {
    final result = await _worker.runTask<String>(
      EpicTask(
        func: EpicFuncName.txFinalize,
        args: {
          "wallet": _getWalletHandle(),
          "slateJson": slateJson,
        },
      ),
    );

    checkForError(result);

    return SlateResponse.fromReceiveResult(result);
  }

  Future<({String slateId, String commitId})> txFinalizeRecord({
    required String slateJson,
  }) async {
    final slate = await txFinalize(slateJson: slateJson);
    return (slateId: slate.slateId, commitId: slate.commitId);
  }

  Future<int> getChainHeight() async {
    return await _worker.runTask<int>(
      EpicTask(
        func: EpicFuncName.getChainHeight,
        args: {
          "config": _config,
        },
      ),
    );
  }

  void updateEpicboxConfig(String epicboxConfig) {
    _epicboxConfig = epicboxConfig;
  }

  /// Get wallet handle (for compatibility)
  String get handle => _getWalletHandle();

  /// Close the wallet and cleanup resources
  Future<void> close({bool save = false}) async {
    if (_walletHandle == null || _isClosing) return;
    _isClosing = true;

    try {
      // Stop listeners first
      await stopListeners();

      // Clear wallet handle
      _walletHandle = null;

      // Dispose worker (kills isolate)
      _worker.dispose();

      // Note: Epic FFI may not have a closeWallet function
      // If it does, you would call it through the worker before disposal
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
