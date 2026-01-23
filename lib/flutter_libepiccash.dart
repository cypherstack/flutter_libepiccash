export 'lib.dart';
export 'epic_wallet.dart';
export 'src/epic_worker.dart';
export 'src/epic_task.dart';
export 'models/balance_data.dart';
export 'models/slate_response.dart';
export 'models/transaction.dart';
export 'utils/epic_errors.dart';
export 'utils/validation_helpers.dart';

import 'flutter_libepiccash_platform_interface.dart';

class FlutterLibepiccash {
  Future<String?> getPlatformVersion() {
    return FlutterLibepiccashPlatform.instance.getPlatformVersion();
  }
}
