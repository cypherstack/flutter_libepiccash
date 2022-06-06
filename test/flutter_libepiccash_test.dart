import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libepiccash/flutter_libepiccash.dart';
import 'package:flutter_libepiccash/flutter_libepiccash_platform_interface.dart';
import 'package:flutter_libepiccash/flutter_libepiccash_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterLibepiccashPlatform
    with MockPlatformInterfaceMixin
    implements FlutterLibepiccashPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterLibepiccashPlatform initialPlatform = FlutterLibepiccashPlatform.instance;

  test('$MethodChannelFlutterLibepiccash is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterLibepiccash>());
  });

  test('getPlatformVersion', () async {
    FlutterLibepiccash flutterLibepiccashPlugin = FlutterLibepiccash();
    MockFlutterLibepiccashPlatform fakePlatform = MockFlutterLibepiccashPlatform();
    FlutterLibepiccashPlatform.instance = fakePlatform;

    expect(await flutterLibepiccashPlugin.getPlatformVersion(), '42');
  });
}
