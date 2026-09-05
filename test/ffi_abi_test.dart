import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the C header matches every exported Rust function', () {
    final rustSource = File('rust/src/ffi.rs').readAsStringSync();
    final headerSource =
        File('rust/include/epic_cash_wallet.h').readAsStringSync();

    final rustFunctions = _rustFunctions(rustSource);
    final headerFunctions = _headerFunctions(headerSource);

    expect(headerFunctions.keys.toSet(), rustFunctions.keys.toSet());
    for (final name in rustFunctions.keys) {
      expect(
        headerFunctions[name],
        rustFunctions[name],
        reason: '$name has different arity in Rust and the C header',
      );
    }
  });
}

Map<String, int> _rustFunctions(String source) {
  final pattern = RegExp(
    r'pub\s+unsafe\s+extern\s+"C"\s+fn\s+([A-Za-z_]\w*)\s*'
    r'\((.*?)\)\s*(?:->\s*[^\{]+)?\{',
    multiLine: true,
    dotAll: true,
  );

  return {
    for (final match in pattern.allMatches(source))
      match.group(1)!: _argumentCount(match.group(2)!),
  };
}

Map<String, int> _headerFunctions(String source) {
  final pattern = RegExp(
    r'^(?:const\s+char\s*\*|void\s*\*|void\s+)'
    r'([A-Za-z_]\w*)\s*\((.*?)\);',
    multiLine: true,
    dotAll: true,
  );

  return {
    for (final match in pattern.allMatches(source))
      match.group(1)!: _argumentCount(match.group(2)!),
  };
}

int _argumentCount(String arguments) {
  final normalized = arguments.trim();
  if (normalized.isEmpty || normalized == 'void') {
    return 0;
  }
  return normalized
      .split(',')
      .where((argument) => argument.trim().isNotEmpty)
      .length;
}
