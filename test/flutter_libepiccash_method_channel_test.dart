import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libepiccash/flutter_libepiccash_method_channel.dart';

void main() {
  MethodChannelFlutterLibepiccash platform = MethodChannelFlutterLibepiccash();
  const MethodChannel channel = MethodChannel('flutter_libepiccash');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
