enum EpicFuncName {
  getMnemonic,
  initWallet,
  recoverWallet,
  openWallet,
  getWalletInfo,
  scanOutputs,
  createTransaction,
  getTransactions,
  cancelTransaction,
  getChainHeight,
  getAddressInfo,
  getTransactionFees,
  txHttpSend,
  txReceive,
  txFinalize,
  validateSendAddress,
  startEpicboxListener,
  stopEpicboxListener,
  isEpicboxListenerRunning,
}

class EpicTask {
  final EpicFuncName func;

  final Map<String, dynamic>? args;

  final String? id;

  const EpicTask({
    required this.func,
    this.args,
    this.id,
  });

  Map<String, dynamic> toMap() {
    return {
      'func': func.name,
      'args': args,
      'id': id,
    };
  }

  factory EpicTask.fromMap(Map<String, dynamic> map) {
    return EpicTask(
      func: EpicFuncName.values.byName(map['func'] as String),
      args: map['args'] as Map<String, dynamic>?,
      id: map['id'] as String?,
    );
  }

  EpicTask withId(String id) {
    return EpicTask(
      func: func,
      args: args,
      id: id,
    );
  }
}

class EpicTaskResponse {
  final String id;

  final dynamic result;

  final String? error;

  const EpicTaskResponse({
    required this.id,
    this.result,
    this.error,
  });

  bool get isSuccess => error == null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'result': result,
      'error': error,
    };
  }

  factory EpicTaskResponse.fromMap(Map<String, dynamic> map) {
    return EpicTaskResponse(
      id: map['id'] as String,
      result: map['result'],
      error: map['error'] as String?,
    );
  }
}
