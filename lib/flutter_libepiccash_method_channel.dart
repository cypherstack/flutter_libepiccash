import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_libepiccash_platform_interface.dart';

/// An implementation of [FlutterLibepiccashPlatform] that uses method channels.
class MethodChannelFlutterLibepiccash extends FlutterLibepiccashPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_libepiccash');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
