import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libepiccash/src/errors.dart';

void main() {
  test('No error for ok=true envelope', () {
    expect(
      () => throwIfError('{"ok":true, "data": {"x":1}}'),
      returnsNormally,
    );
  });

  test('Throws for ok=false envelope', () {
    expect(
      () => throwIfError('{"ok":false, "code":"E001","message":"boom"}'),
      throwsA(isA<EpicFfiException>().having((e) => e.message, 'message', 'boom')),
    );
  });

  test('Throws for legacy plain error', () {
    expect(
      () => throwIfError('Error something bad'),
      throwsA(isA<EpicFfiException>()),
    );
  });
}

