import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'package:uuid/uuid.dart';
import 'epic_task.dart';
import '../epic_cash.dart' as epic_ffi;

class EpicWorker {
  EpicWorker._({
    required Isolate isolate,
    required SendPort sendPort,
    required ReceivePort receivePort,
  })  : _isolate = isolate,
        _sendPort = sendPort,
        _receivePort = receivePort {
    // Listen for responses from the worker isolate
    _receivePort.listen(_handleResponse);
  }

  final Isolate _isolate;
  final SendPort _sendPort;
  final ReceivePort _receivePort;

  final Map<String, Completer<dynamic>> _pendingTasks = {};

  static const _uuid = Uuid();

  bool _disposed = false;

  static Future<EpicWorker> spawn() async {
    // Create a receive port for this main isolate
    final receivePort = ReceivePort();

    // Spawn the worker isolate, passing our send port
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      receivePort.sendPort,
      debugName: 'EpicWorker',
    );

    // Wait for the worker to send back its send port
    final sendPort = await receivePort.first as SendPort;

    // Create a new receive port for ongoing communication
    final messageReceivePort = ReceivePort();

    // Send our new receive port to the worker
    sendPort.send(messageReceivePort.sendPort);

    return EpicWorker._(
      isolate: isolate,
      sendPort: sendPort,
      receivePort: messageReceivePort,
    );
  }

  Future<T> runTask<T>(EpicTask task) async {
    if (_disposed) {
      throw StateError('EpicWorker has been disposed');
    }

    // Assign a unique ID to this task
    final id = _uuid.v4();
    final taskWithId = task.withId(id);

    // Create a completer to wait for the result
    final completer = Completer<T>.sync();
    _pendingTasks[id] = completer;

    // Send the task to the worker
    _sendPort.send(taskWithId.toMap());

    return completer.future;
  }

  /// Handle responses from the worker isolate
  void _handleResponse(dynamic message) {
    if (message is! Map<String, dynamic>) {
      return;
    }

    final response = EpicTaskResponse.fromMap(message);
    final completer = _pendingTasks.remove(response.id);

    if (completer == null) {
      // Task not found - may have been cancelled or timed out
      return;
    }

    if (response.isSuccess) {
      completer.complete(response.result);
    } else {
      completer.completeError(
        Exception('Epic worker error: ${response.error}'),
      );
    }
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);

    // Complete any pending tasks with errors
    for (final completer in _pendingTasks.values) {
      completer.completeError(
        Exception('EpicWorker was disposed'),
      );
    }
    _pendingTasks.clear();
  }

  /// Entry point for the worker isolate
  static void _isolateEntryPoint(SendPort mainSendPort) {
    // Create a receive port for this worker
    final receivePort = ReceivePort();

    // Send our send port back to main
    mainSendPort.send(receivePort.sendPort);

    // Wait for main's send port
    late SendPort sendToMain;

    // Process tasks sequentially to avoid overlapping FFI calls.
    () async {
      await for (final message in receivePort) {
        // First message is the send port
        if (message is SendPort) {
          sendToMain = message;
          continue;
        }

        // Subsequent messages are tasks
        if (message is! Map<String, dynamic>) {
          continue;
        }

        final task = EpicTask.fromMap(message);
        final id = task.id!;

        try {
          final result = await _executeTask(task);
          sendToMain.send(EpicTaskResponse(
            id: id,
            result: result,
          ).toMap());
        } catch (e) {
          sendToMain.send(EpicTaskResponse(
            id: id,
            error: e.toString(),
          ).toMap());
        }
      }
    }();
  }

  /// Execute an Epic FFI task
  static Future<dynamic> _executeTask(EpicTask task) async {
    final args = task.args ?? {};

    switch (task.func) {
      case EpicFuncName.getMnemonic:
        return epic_ffi.walletMnemonic();

      case EpicFuncName.initWallet:
        return epic_ffi.initWallet(
          args['config'] as String,
          args['mnemonic'] as String,
          args['password'] as String,
          args['name'] as String,
        );

      case EpicFuncName.recoverWallet:
        return epic_ffi.recoverWallet(
          args['config'] as String,
          args['password'] as String,
          args['mnemonic'] as String,
          args['name'] as String,
        );

      case EpicFuncName.openWallet:
        return epic_ffi.openWallet(
          args['config'] as String,
          args['password'] as String,
        );

      case EpicFuncName.getWalletInfo:
        return await epic_ffi.getWalletInfo(
          args['wallet'] as String,
          args['refreshFromNode'] as int,
          args['minimumConfirmations'] as int,
        );

      case EpicFuncName.scanOutputs:
        return await epic_ffi.scanOutPuts(
          args['wallet'] as String,
          args['startHeight'] as int,
          args['numberOfBlocks'] as int,
        );

      case EpicFuncName.createTransaction:
        return await epic_ffi.createTransaction(
          args['wallet'] as String,
          args['amount'] as int,
          args['address'] as String,
          args['secretKeyIndex'] as int,
          args['epicboxConfig'] as String,
          args['minimumConfirmations'] as int,
          args['note'] as String,
          returnSlate: args['returnSlate'] as bool? ?? false,
        );

      case EpicFuncName.getTransactions:
        return await epic_ffi.getTransactions(
          args['wallet'] as String,
          args['refreshFromNode'] as int,
        );

      case EpicFuncName.cancelTransaction:
        return epic_ffi.cancelTransaction(
          args['wallet'] as String,
          args['transactionId'] as String,
        );

      case EpicFuncName.getChainHeight:
        return epic_ffi.getChainHeight(
          args['config'] as String,
        );

      case EpicFuncName.getAddressInfo:
        return epic_ffi.getAddressInfo(
          args['wallet'] as String,
          args['index'] as int,
          args['epicboxConfig'] as String,
        );

      case EpicFuncName.getTransactionFees:
        return await epic_ffi.getTransactionFees(
          args['wallet'] as String,
          args['amount'] as int,
          args['minimumConfirmations'] as int,
        );

      case EpicFuncName.txHttpSend:
        return await epic_ffi.txHttpSend(
          args['wallet'] as String,
          args['selectionStrategyIsAll'] as int,
          args['minimumConfirmations'] as int,
          args['message'] as String,
          args['amount'] as int,
          args['address'] as String,
        );

      case EpicFuncName.txReceive:
        return epic_ffi.txReceive(
          args['wallet'] as String,
          args['slateJson'] as String,
        );

      case EpicFuncName.txFinalize:
        return epic_ffi.txFinalize(
          args['wallet'] as String,
          args['slateJson'] as String,
        );

      case EpicFuncName.validateSendAddress:
        final result = epic_ffi.validateSendAddress(
          args['address'] as String,
        );
        return int.tryParse(result) ?? 0;

      case EpicFuncName.startEpicboxListener:
        final pointer = epic_ffi.epicboxListenerStart(
          args['wallet'] as String,
          args['epicboxConfig'] as String,
        );
        return pointer.address;

      case EpicFuncName.stopEpicboxListener:
        final result = epic_ffi.epicboxListenerStop(
          Pointer<Void>.fromAddress(args['pointer'] as int),
        );
        return result.toLowerCase() == 'true';

      case EpicFuncName.isEpicboxListenerRunning:
        return epic_ffi.epicboxListenerIsRunning(
          Pointer<Void>.fromAddress(args['pointer'] as int),
        );
    }
  }
}
