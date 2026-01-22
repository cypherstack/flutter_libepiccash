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

      return BalanceData(
        spendable: _parseAmount(
          json['amount_currently_spendable'],
          'amount_currently_spendable',
        ),
        pending: _parseAmount(
          json['amount_awaiting_finalization'],
          'amount_awaiting_finalization',
        ),
        total: _parseAmount(json['total'], 'total'),
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
