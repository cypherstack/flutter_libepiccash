import 'dart:convert' as convert;

import 'errors.dart';

({String slateId, String commitId}) parseCreateTxResult(String result) {
  try {
    final slate0 = convert.jsonDecode(result);
    if (slate0 is! List || slate0.isEmpty) {
      throw EpicFfiException('Unexpected createTx result format (level 0)');
    }
    final slate = convert.jsonDecode(slate0[0] as String);
    if (slate is! List || slate.length < 2) {
      throw EpicFfiException('Unexpected createTx result format (level 1)');
    }
    final part1 = convert.jsonDecode(slate[0] as String);
    final part2 = convert.jsonDecode(slate[1] as String);

    // part1[0]['tx_slate_id']
    String slateId = '';
    if (part1 is List && part1.isNotEmpty && part1[0] is Map) {
      final m = part1[0] as Map;
      final v = m['tx_slate_id'];
      if (v != null) slateId = v.toString();
    }

    // part2['tx']['body']['outputs'][0]['commit']
    String commitId = '';
    if (part2 is Map) {
      final tx = part2['tx'];
      if (tx is Map) {
        final body = tx['body'];
        if (body is Map) {
          final outs = body['outputs'];
          if (outs is List && outs.isNotEmpty) {
            final first = outs.first;
            if (first is Map && first['commit'] != null) {
              commitId = first['commit'].toString();
            }
          }
        }
      }
    }

    if (slateId.isEmpty) {
      throw EpicFfiException('Missing slateId in createTx result');
    }

    return (slateId: slateId, commitId: commitId);
  } catch (e) {
    if (e is EpicFfiException) rethrow;
    throw EpicFfiException('Failed to parse createTx result: $e');
  }
}

({bool strategyUseAll, int total, int fee}) parseTxFees(String feesJson) {
  try {
    final decoded = convert.jsonDecode(feesJson);
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      throw EpicFfiException('Unexpected fees result format');
    }
    final item = decoded.first as Map;
    final strategy = item['selection_strategy_is_use_all'] == true;
    final total = (item['total'] as num).toInt();
    final fee = (item['fee'] as num).toInt();
    return (strategyUseAll: strategy, total: total, fee: fee);
  } catch (e) {
    if (e is EpicFfiException) rethrow;
    throw EpicFfiException('Failed to parse tx fees: $e');
  }
}

