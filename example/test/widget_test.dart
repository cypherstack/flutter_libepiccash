import 'package:flutter/services.dart';
import 'package:flutter_libepiccash_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Shows wallet management when storage is unavailable', (
    WidgetTester tester,
  ) async {
    // Keep the startup test independent of native storage plugins and wallets
    // on the developer's machine. A missing documents directory is handled by
    // the application as an empty wallet list.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Manage Wallets'), findsOneWidget);
    expect(find.text('No wallets found.'), findsOneWidget);
    expect(find.text('Create Wallet'), findsOneWidget);
    expect(find.text('Recover Wallet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
