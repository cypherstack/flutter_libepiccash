class EpicWalletException implements Exception {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  EpicWalletException(
    this.message, {
    this.code,
    this.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' (code: $code)' : '';
    return 'EpicWalletException: $message$codeStr';
  }
}

class EpicWalletClosedException extends EpicWalletException {
  EpicWalletClosedException([String? operation])
      : super(
          'Wallet has been closed${operation != null ? '. Cannot perform: $operation' : ''}',
          code: 'WALLET_CLOSED',
        );
}

class EpicFFIException extends EpicWalletException {
  EpicFFIException(String message, {String? code, StackTrace? stackTrace})
      : super(message, code: code, stackTrace: stackTrace);

  factory EpicFFIException.fromResult(String result) {
    if (result.startsWith('Error ')) {
      return EpicFFIException(result.substring(6), code: 'FFI_ERROR');
    }
    return EpicFFIException(result, code: 'UNKNOWN_ERROR');
  }
}

class EpicParseException extends EpicWalletException {
  final dynamic rawData;

  EpicParseException(
    String message, {
    this.rawData,
    StackTrace? stackTrace,
  }) : super(message, code: 'PARSE_ERROR', stackTrace: stackTrace);
}

class EpicWalletCreationException extends EpicWalletException {
  EpicWalletCreationException(String message, {StackTrace? stackTrace})
      : super(message, code: 'CREATION_FAILED', stackTrace: stackTrace);
}

class EpicTransactionException extends EpicWalletException {
  EpicTransactionException(String message,
      {String? code, StackTrace? stackTrace})
      : super(message, code: code ?? 'TX_ERROR', stackTrace: stackTrace);
}

void checkForError(String result) {
  if (result.startsWith('Error ')) {
    throw EpicFFIException.fromResult(result);
  }
  if (result.toUpperCase().contains('ERROR')) {
    throw EpicFFIException(result, code: 'FFI_ERROR');
  }
}
