import 'dart:convert';

import '../utils/epic_errors.dart';

class SlateResponse {
  final String slateId;
  final String commitId;
  final String slateJson;

  SlateResponse({
    required this.slateId,
    required this.commitId,
    required this.slateJson,
  });

  // Epic FFI txReceive returns: result -> slate0[0] -> parsedSlate (Map)
  factory SlateResponse.fromReceiveResult(String result) {
    try {
      final slate0 = jsonDecode(result);
      if (slate0 is! List || slate0.isEmpty) {
        throw FormatException(
            'Expected array at top level, got ${slate0.runtimeType}');
      }

      final slateResponse = slate0[0] as String;
      final parsedSlate = jsonDecode(slateResponse);

      if (parsedSlate is! Map) {
        throw FormatException(
            'Expected Map for slate, got ${parsedSlate.runtimeType}');
      }

      final slateId = parsedSlate['id'] as String;
      final List<dynamic>? outputs =
          parsedSlate['tx']?['body']?['outputs'] as List?;
      final commitId = (outputs == null || outputs.isEmpty)
          ? ''
          : outputs[0]['commit'] as String;

      return SlateResponse(
        slateId: slateId,
        commitId: commitId,
        slateJson: slateResponse,
      );
    } on FormatException catch (e, s) {
      throw EpicParseException(
        'Failed to parse receive slate response: ${e.message}',
        rawData: result,
        stackTrace: s,
      );
    } on TypeError catch (e, s) {
      throw EpicParseException(
        'Type error parsing receive slate response: $e',
        rawData: result,
        stackTrace: s,
      );
    } catch (e, s) {
      throw EpicParseException(
        'Unexpected error parsing receive slate response: $e',
        rawData: result,
        stackTrace: s,
      );
    }
  }

  // Epic FFI returns: result -> slate0[0] -> slate[0,1] -> part1, part2
  factory SlateResponse.fromResult(String result) {
    try {
      final slate0 = jsonDecode(result);
      if (slate0 is! List || slate0.isEmpty) {
        throw FormatException(
            'Expected array at top level, got ${slate0.runtimeType}');
      }

      final slate = jsonDecode(slate0[0] as String);
      if (slate is! List || slate.length < 2) {
        throw FormatException(
            'Expected array with 2 elements, got ${slate.runtimeType}');
      }

      final part1 = jsonDecode(slate[0] as String);
      final part2 = jsonDecode(slate[1] as String);

      return SlateResponse(
        slateId: _extractSlateId(part1, part2),
        commitId: _extractCommitId(part2),
        slateJson: slate[1] as String,
      );
    } on FormatException catch (e, s) {
      throw EpicParseException(
        'Failed to parse slate response: ${e.message}',
        rawData: result,
        stackTrace: s,
      );
    } on TypeError catch (e, s) {
      throw EpicParseException(
        'Type error parsing slate response: $e',
        rawData: result,
        stackTrace: s,
      );
    } catch (e, s) {
      throw EpicParseException(
        'Unexpected error parsing slate response: $e',
        rawData: result,
        stackTrace: s,
      );
    }
  }

  static String _extractSlateId(dynamic part1, dynamic part2) {
    if (part2 is Map && part2['id'] != null) {
      return part2['id'] as String;
    }

    if (part1 is List && part1.isNotEmpty) {
      final first = part1[0];
      if (first is Map && first['tx_slate_id'] != null) {
        return first['tx_slate_id'] as String;
      }
    }

    throw FormatException('Could not find slate ID in response');
  }

  static String _extractCommitId(dynamic part2) {
    if (part2 is! Map) {
      throw FormatException('part2 is not a Map: ${part2.runtimeType}');
    }

    final tx = part2['tx'];
    if (tx == null) {
      throw FormatException('Missing "tx" field in part2');
    }

    final body = tx['body'];
    if (body == null) {
      throw FormatException('Missing "tx.body" field');
    }

    final outputs = body['outputs'];
    if (outputs == null) {
      throw FormatException('Missing "tx.body.outputs" field');
    }

    if (outputs is! List) {
      throw FormatException('outputs is not a List: ${outputs.runtimeType}');
    }

    if (outputs.isEmpty) {
      return ''; // Empty commit ID for empty outputs
    }

    final firstOutput = outputs[0];
    if (firstOutput is! Map) {
      throw FormatException(
          'First output is not a Map: ${firstOutput.runtimeType}');
    }

    final commit = firstOutput['commit'];
    if (commit == null) {
      throw FormatException('Missing "commit" field in first output');
    }

    return commit as String;
  }

  ({String slateId, String commitId, String slateJson}) toRecord() {
    return (slateId: slateId, commitId: commitId, slateJson: slateJson);
  }

  @override
  String toString() {
    return 'SlateResponse(slateId: $slateId, commitId: $commitId, '
        'slateJson: ${slateJson.substring(0, slateJson.length > 50 ? 50 : slateJson.length)}...)';
  }
}
