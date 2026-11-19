import 'dart:convert';

import '../utils/epic_errors.dart';

class BalanceData {
  final double spendable;
  final double pending;
  final double total;
  final double awaitingFinalization;

  BalanceData({
    required this.spendable,
    required this.pending,
    required this.total,
    required this.awaitingFinalization,
  });

  factory BalanceData.fromJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      // epic-wallet's total counts outputs locked by an unconfirmed send;
      // grin-wallet and mwc-wallet leave them out. Their change is already in
      // amount_awaiting_finalization, so drop the locked part here to give
      // total the same meaning as in grin and MWC.
      final reportedTotal = _parseAmount(json['total'], 'total');
      final locked = json['amount_locked'] == null
          ? 0.0
          : _parseAmount(json['amount_locked'], 'amount_locked');
      // Subtract in nano-EPIC so the result prints like the wallet's amounts.
      final totalNano = (reportedTotal * 1e8).round() - (locked * 1e8).round();
      final total = totalNano / 1e8;

      return BalanceData(
        spendable: _parseAmount(
          json['amount_currently_spendable'],
          'amount_currently_spendable',
        ),
        pending: _parseAmount(
          json['amount_awaiting_finalization'],
          'amount_awaiting_finalization',
        ),
        total: total < 0 ? 0.0 : total,
        awaitingFinalization: _parseAmount(
          json['amount_awaiting_finalization'],
          'amount_awaiting_finalization',
        ),
      );
    } on FormatException catch (e, s) {
      throw EpicParseException(
        'Failed to parse balance data: ${e.message}',
        rawData: jsonString,
        stackTrace: s,
      );
    } catch (e, s) {
      throw EpicParseException(
        'Unexpected error parsing balance data: $e',
        rawData: jsonString,
        stackTrace: s,
      );
    }
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

  ({
    double spendable,
    double pending,
    double total,
    double awaitingFinalization,
  }) toRecord() {
    return (
      spendable: spendable,
      pending: pending,
      total: total,
      awaitingFinalization: awaitingFinalization,
    );
  }

  @override
  String toString() {
    return 'BalanceData(spendable: $spendable, pending: $pending, '
        'total: $total, awaitingFinalization: $awaitingFinalization)';
  }
}
