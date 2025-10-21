// Local alias to dart:convert to keep imports contained in this file.
import 'dart:convert' as _json;

class EpicFfiException implements Exception {
  final String? code;
  final String message;
  final String? raw;

  EpicFfiException(this.message, {this.code, this.raw});

  @override
  String toString() =>
      'EpicFfiException(code: ${code ?? '-'}, message: $message)';
}

/// Inspect a raw FFI string result and throw a typed exception on error.
/// Supported formats:
/// - JSON envelope: {"ok": false, "code": "...", "message": "..."}
/// - Plain string starting with "Error " or containing "ERROR"
void throwIfError(String result) {
  final trimmed = result.trim();
  // Try envelope first.
  if (trimmed.startsWith('{')) {
    dynamic decoded;
    try {
      decoded = _tryDecodeJson(trimmed);
    } catch (_) {
      decoded = null; // Fall through to legacy checks.
    }
    if (decoded is Map && decoded.containsKey('ok')) {
      final ok = decoded['ok'] == true;
      if (!ok) {
        final code = decoded['code']?.toString();
        final msg = decoded['message']?.toString() ?? 'Unknown error';
        throw EpicFfiException(msg, code: code, raw: result);
      }
    }
  }

  // Legacy plain-string errors.
  if (trimmed.startsWith('Error ') || trimmed.toUpperCase().contains('ERROR')) {
    throw EpicFfiException(trimmed, raw: result);
  }
}

dynamic _tryDecodeJson(String s) {
  // Avoid importing dart:convert here to keep the helper light; caller can
  // decode again as needed. Minimal local decode via dart:convert would be fine
  // but we keep it isolated to avoid extra deps in this leaf file.
  // ignore: avoid_dynamic_calls
  return _jsonDecode(s);
}

// Lightweight indirection to allow testing/mocking if needed.
dynamic _jsonDecode(String s) => _json.jsonDecode(s);
