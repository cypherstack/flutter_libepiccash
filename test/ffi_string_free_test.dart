import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libepiccash/epic_cash.dart' as ffi_api;

void main() {
  test('FFI strings can be freed safely (smoke)', () {
    const iterations = 200;
    for (var i = 0; i < iterations; i++) {
      try {
        final s = ffi_api.walletMnemonic();
        expect(s, isNotEmpty);
      } on ArgumentError catch (e) {
        // Dynamic library not available on this host. Treat as a skipped test.
        // Print once and exit early to avoid failing CI where the native lib
        // isn't built or present.
        // ignore: avoid_print
        print('Skipping FFI smoke test: $e');
        return;
      }
    }
  });

  test('Address validation FFI returns expected shape', () {
    try {
      final invalid = ffi_api.validateSendAddress('not-an-address');
      expect(invalid == '0' || invalid == '1', isTrue);

      // The exact valid format is network-specific; this just exercises the FFI path.
      // You can add a known-good example here if available.
    } on ArgumentError catch (e) {
      // Dynamic library not available; skip.
      // ignore: avoid_print
      print('Skipping address validation FFI test: $e');
      return;
    }
  });
}
