import 'dart:convert' as convert;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libepiccash/src/errors.dart';
import 'package:flutter_libepiccash/src/parsing.dart';

void main() {
  test('parseBalances extracts amounts', () {
    final m = {
      'amount_currently_spendable': 1.5,
      'amount_awaiting_finalization': 0.25,
      'total': 1.75,
    };
    final json = convert.jsonEncode(m);
    final res = parseBalances(json);
    expect(res.spendable, 1.5);
    expect(res.awaitingFinalization, 0.25);
    expect(res.total, 1.75);
  });

  test('throw on bad balances', () {
    expect(() => parseBalances('[]'), throwsA(isA<EpicFfiException>()));
  });
}

