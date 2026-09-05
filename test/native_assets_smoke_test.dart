import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads the Rust native asset and releases its result', () {
    final mnemonic = walletMnemonic();

    expect(mnemonic.trim().split(RegExp(r'\s+')), hasLength(24));
  });
}
