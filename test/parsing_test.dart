import 'dart:convert' as convert;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libepiccash/src/parsing.dart';

void main() {
  test('parseCreateTxResult extracts slate and commit', () {
    // Build nested shape expected by parser.
    final part1 = convert.jsonEncode([
      {"tx_slate_id": "abc-123"}
    ]);
    final part2 = convert.jsonEncode({
      "tx": {
        "body": {
          "outputs": [
            {"commit": "COMMIT-ID"}
          ]
        }
      }
    });
    final slate = convert.jsonEncode([part1, part2]);
    final top = convert.jsonEncode([slate]);

    final res = parseCreateTxResult(top);
    expect(res.slateId, 'abc-123');
    expect(res.commitId, 'COMMIT-ID');
  });

  test('parseTxFees extracts fields', () {
    final json = '[{"selection_strategy_is_use_all":true, "total": 101, "fee": 1}]';
    final res = parseTxFees(json);
    expect(res.strategyUseAll, isTrue);
    expect(res.total, 101);
    expect(res.fee, 1);
  });
}
