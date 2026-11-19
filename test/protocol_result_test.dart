import 'dart:convert';

import 'package:flutter_libepiccash/models/transaction.dart';
import 'package:flutter_libepiccash/models/slate_response.dart';
import 'package:flutter_libepiccash/utils/epic_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an error word inside successful JSON is not a native failure', () {
    expect(
      () => checkForError(jsonEncode({'message': 'no error occurred'})),
      returnsNormally,
    );
  });

  test('native error prefixes still throw', () {
    expect(
      () => checkForError('Error wallet unavailable'),
      throwsA(isA<EpicFFIException>()),
    );
    expect(
      () => checkForError('  ERROR: wallet unavailable'),
      throwsA(isA<EpicFFIException>()),
    );
  });

  test('null native messages remain null', () {
    final message = Message.fromJson({
      'id': '1',
      'public_key': 'key',
      'message': null,
      'message_sig': null,
    });

    expect(message.message, isNull);
    expect(message.messageSig, isNull);
  });

  test('finalize metadata reports whether the transaction was posted', () {
    final slate = jsonEncode({
      'id': 'slate-id',
      'tx': {
        'body': {
          'outputs': <Object>[],
        },
      },
    });

    expect(
      SlateResponse.fromReceiveResult(
        jsonEncode([slate, jsonEncode({'posted': false})]),
      ).posted,
      isFalse,
    );
  });
}
