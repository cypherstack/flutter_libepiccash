import 'flutter_libepiccash_platform_interface.dart';

export 'epic_wallet.dart';
export 'lib.dart';
export 'models/balance_data.dart';
export 'models/slate_response.dart';
export 'models/transaction.dart';
export 'src/epic_task.dart';
export 'src/epic_worker.dart';
export 'utils/epic_errors.dart';
export 'utils/validation_helpers  /// Retained temporarily for source compatibility with the former plugin.
  @Deprecated('This package no longer uses a platform channel.')
  Future<String?> getPlatformVersion() async => Platform.operatingSystemVersion;
}
