import 'dart:async';
import 'dart:isolate';

import '../epic_cash.dart' as ffi_api;

class FfiWorker {
  FfiWorker._();

  static final FfiWorker instance = FfiWorker._();

  SendPort? _sendPort;
  int _nextId = 0;
  final Map<int, Completer<dynamic>> _pending = {};

  Future<void> _ensureStarted() async {
    if (_sendPort != null) return;
    final ready = Completer<SendPort>();
    final receive = ReceivePort();
    await Isolate.spawn(_entry, receive.sendPort);
    receive.listen((msg) {
      if (msg is SendPort) {
        _sendPort = msg;
        ready.complete(msg);
      } else if (msg is Map) {
        final id = msg['id'] as int;
        final ok = msg['ok'] as bool;
        final completer = _pending.remove(id);
        if (completer != null) {
          if (ok) {
            completer.complete(msg['data']);
          } else {
            completer.completeError(Exception(msg['error'] as String));
          }
        }
      }
    });
    await ready.future;
  }

  Future<T> call<T>(String op, Map<String, dynamic> args) async {
    await _ensureStarted();
    final id = _nextId++;
    final completer = Completer<T>();
    _pending[id] = completer as Completer<dynamic>;
    _sendPort!.send({'id': id, 'op': op, 'args': args});
    return completer.future;
  }

  static void _entry(SendPort host) {
    final inbox = ReceivePort();
    host.send(inbox.sendPort);
    inbox.listen((message) async {
      if (message is! Map) return;
      final id = message['id'] as int;
      final op = message['op'] as String;
      final args = (message['args'] as Map).cast<String, dynamic>();
      try {
        final data = await _dispatch(op, args);
        host.send({'id': id, 'ok': true, 'data': data});
      } catch (e) {
        host.send({'id': id, 'ok': false, 'error': e.toString()});
      }
    });
  }

  static Future<dynamic> _dispatch(String op, Map<String, dynamic> a) async {
    switch (op) {
      case 'walletMnemonic':
        return ffi_api.walletMnemonic();
      case 'initWallet':
        return ffi_api.initWallet(
          a['config'] as String,
          a['mnemonic'] as String,
          a['password'] as String,
          a['name'] as String,
        );
      case 'getWalletInfo':
        return ffi_api.getWalletInfo(
          a['wallet'] as String,
          a['refreshFromNode'] as int,
          a['minimumConfirmations'] as int,
        );
      case 'scanOutPuts':
        return ffi_api.scanOutPuts(
          a['wallet'] as String,
          a['startHeight'] as int,
          a['numberOfBlocks'] as int,
        );
      case 'createTransaction':
        return ffi_api.createTransaction(
          a['wallet'] as String,
          a['amount'] as int,
          a['address'] as String,
          a['secretKeyIndex'] as int,
          a['epicboxConfig'] as String,
          a['minimumConfirmations'] as int,
          a['note'] as String,
        );
      case 'getTransactions':
        return ffi_api.getTransactions(
          a['wallet'] as String,
          a['refreshFromNode'] as int,
        );
      case 'cancelTransaction':
        return ffi_api.cancelTransaction(
          a['wallet'] as String,
          a['transactionId'] as String,
        );
      case 'getChainHeight':
        return ffi_api.getChainHeight(a['config'] as String);
      case 'getAddressInfo':
        return ffi_api.getAddressInfo(
          a['wallet'] as String,
          a['index'] as int,
          a['epicboxConfig'] as String,
        );
      case 'validateSendAddress':
        return ffi_api.validateSendAddress(a['address'] as String);
      case 'getTransactionFees':
        return ffi_api.getTransactionFees(
          a['wallet'] as String,
          a['amount'] as int,
          a['minimumConfirmations'] as int,
        );
      case 'deleteWallet':
        return ffi_api.deleteWallet(
          a['wallet'] as String,
          a['config'] as String,
        );
      case 'openWallet':
        return ffi_api.openWallet(
          a['config'] as String,
          a['password'] as String,
        );
      case 'txHttpSend':
        return ffi_api.txHttpSend(
          a['wallet'] as String,
          a['selectionStrategyIsAll'] as int,
          a['minimumConfirmations'] as int,
          a['message'] as String,
          a['amount'] as int,
          a['address'] as String,
        );
      case 'recoverWallet':
        return ffi_api.recoverWallet(
          a['config'] as String,
          a['password'] as String,
          a['mnemonic'] as String,
          a['name'] as String,
        );
      default:
        throw UnsupportedError('Unknown FFI op: $op');
    }
  }
}
