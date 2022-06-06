
import 'flutter_libepiccash_platform_interface.dart';

class FlutterLibepiccash {
  Future<String?> getPlatformVersion() {
    return FlutterLibepiccashPlatform.instance.getPlatformVersion();
  }
}
