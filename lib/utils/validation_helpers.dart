import 'dart:convert';

import 'epic_errors.dart';

int parseInt(dynamic value, String fieldName) {
  if (value == null) {
    throw FormatException('Missing required field: $fieldName');
  }

  if (value is int) {
    return value;
  }

  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw FormatException(
        'Invalid integer format for $fieldName: "$value"',
      );
    }
    return parsed;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException(
    'Invalid type for $fieldName: expected int, got ${value.runtimeType}',
  );
}

String parseString(dynamic value, String fieldName, {bool allowEmpty = true}) {
  if (value == null) {
    throw FormatException('Missing required field: $fieldName');
  }

  if (value is! String) {
    throw FormatException(
      'Invalid type for $fieldName: expected String, got ${value.runtimeType}',
    );
  }

  if (!allowEmpty && value.isEmpty) {
    throw FormatException('Field $fieldName cannot be empty');
  }

  return value;
}

bool parseBool(dynamic value, String fieldName) {
  if (value == null) {
    throw FormatException('Missing required field: $fieldName');
  }

  if (value is bool) {
    return value;
  }

  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
    throw FormatException(
      'Invalid boolean format for $fieldName: "$value"',
    );
  }

  if (value is int) {
    return value != 0;
  }

  throw FormatException(
    'Invalid type for $fieldName: expected bool, got ${value.runtimeType}',
  );
}

Map<String, dynamic> parseJsonObject(String jsonString, String context) {
  try {
    final parsed = jsonDecode(jsonString);
    if (parsed is! Map<String, dynamic>) {
      throw FormatException(
        'Expected JSON object, got ${parsed.runtimeType}',
      );
    }
    return parsed;
  } on FormatException catch (e, s) {
    throw EpicParseException(
      'Failed to parse JSON for $context: ${e.message}',
      rawData: jsonString,
      stackTrace: s,
    );
  } catch (e, s) {
    throw EpicParseException(
      'Unexpected error parsing JSON for $context: $e',
      rawData: jsonString,
      stackTrace: s,
    );
  }
}

int bigIntToSafeInt(BigInt value, String fieldName) {
  const maxSafeInt = 9223372036854775807;
  const minSafeInt = -9223372036854775808;

  if (value > BigInt.from(maxSafeInt)) {
    throw RangeError(
      '$fieldName exceeds maximum safe integer: $value > $maxSafeInt',
    );
  }

  if (value < BigInt.from(minSafeInt)) {
    throw RangeError(
      '$fieldName below minimum safe integer: $value < $minSafeInt',
    );
  }

  return value.toInt();
}
