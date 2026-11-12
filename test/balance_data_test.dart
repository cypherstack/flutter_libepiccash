import 'dart:convert';

import 'package:flutter_libepiccash/models/balance_data.dart';
import 'package:flutter_test/flutter_test.dart';

String _info({
  required double total,
  required double locked,
  required double awaitingFinalization,
  required double spendable,
}) => jsonEncode({
  'last_confirmed_height': 1500,
  'minimum_confirmations': 10,
  'total': total,
  'amount_awaiting_finalization': awaitingFinalization,
  'amount_awaiting_confirmation': 0.0,
  'amount_immature': 0.0,
  'amount_currently_spendable': spendable,
  'amount_locked': locked,
});

void main() {
  test('pending send: total leaves out the locked input', () {
    // A 30 EPIC output locked by a 5 EPIC send; the 24.992 change is
    // awaiting finalization. epic-wallet reports total 30.
    final b = BalanceData.fromJson(
      _info(total: 30, locked: 30, awaitingFinalization: 24.992, spendable: 0),
    );
    expect(b.total, 0);
    expect(b.awaitingFinalization, 24.992);
    expect(b.pending, 24.992);
    expect(b.spendable, 0);
    // What Stack shows: total + awaitingFinalization.
    expect(b.total + b.awaitingFinalization, 24.992);
  });

  test('idle wallet: total unchanged', () {
    final b = BalanceData.fromJson(
      _info(total: 30, locked: 0, awaitingFinalization: 0, spendable: 30),
    );
    expect(b.total, 30);
    expect(b.spendable, 30);
    expect(b.toRecord(), (
      spendable: 30.0,
      pending: 0.0,
      total: 30.0,
      awaitingFinalization: 0.0,
    ));
  });

  test('no float noise from the subtraction', () {
    // 54.992 - 30 in plain doubles is 24.991999999999997.
    final b = BalanceData.fromJson(
      _info(
        total: 54.992,
        locked: 30,
        awaitingFinalization: 24.992,
        spendable: 0,
      ),
    );
    expect(b.total.toString(), '24.992');
  });

  test('total is clamped at zero', () {
    final b = BalanceData.fromJson(
      _info(total: 1, locked: 2, awaitingFinalization: 0, spendable: 0),
    );
    expect(b.total, 0);
  });

  test('missing amount_locked is treated as zero', () {
    final b = BalanceData.fromJson(
      jsonEncode({
        'total': 12.5,
        'amount_awaiting_finalization': 0,
        'amount_currently_spendable': 12.5,
      }),
    );
    expect(b.total, 12.5);
  });
}
