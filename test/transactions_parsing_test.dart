import 'dart:convert' as convert;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libepiccash/src/parsing.dart';
import 'package:flutter_libepiccash/models/transaction.dart';

void main() {
  test('parseTransactionsRawList returns list and maps to model', () {
    final tx = {
      'parent_key_id': 'key123',
      'id': 1,
      'tx_slate_id': 's1',
      'tx_type': 'TxSent',
      'creation_ts': 'ts',
      'confirmation_ts': 'ts2',
      'confirmed': true,
      'num_inputs': 1,
      'num_outputs': 1,
      'amount_credited': '0',
      'amount_debited': '0',
    };
    final json = convert.jsonEncode([tx]);
    final list = parseTransactionsRawList(json);
    expect(list, hasLength(1));
    final model = Transaction.fromJson(list.first);
    expect(model.id, 1);
    expect(model.txType, TransactionType.TxSent);
  });
}

