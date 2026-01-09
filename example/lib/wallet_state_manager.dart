import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages persistent state for wallets (last scanned block, etc.).
class WalletStateManager {
  static const _storage = FlutterSecureStorage();

  static const String _lastScannedBlockPrefix = 'last_scanned_block_';
  static const String _defaultStartHeightPrefix = 'default_start_height_';

  /// Get the last scanned block height for a wallet.
  static Future<int> getLastScannedBlock(String walletName) async {
    final key = '$_lastScannedBlockPrefix$walletName';
    final value = await _storage.read(key: key);
    if (value == null) return 0;
    return int.tryParse(value) ?? 0;
  }

  /// Save the last scanned block height for a wallet.
  static Future<void> saveLastScannedBlock(String walletName, int height) async {
    final key = '$_lastScannedBlockPrefix$walletName';
    await _storage.write(key: key, value: height.toString());
  }

  /// Get the default start height for a wallet (used for recovery/initial scan).
  static Future<int> getDefaultStartHeight(String walletName) async {
    final key = '$_defaultStartHeightPrefix$walletName';
    final value = await _storage.read(key: key);
    if (value == null) return 0;
    return int.tryParse(value) ?? 0;
  }

  /// Save the default start height for a wallet.
  static Future<void> saveDefaultStartHeight(String walletName, int height) async {
    final key = '$_defaultStartHeightPrefix$walletName';
    await _storage.write(key: key, value: height.toString());
  }

  /// Clear all state for a wallet (useful when deleting).
  static Future<void> clearWalletState(String walletName) async {
    await _storage.delete(key: '$_lastScannedBlockPrefix$walletName');
    await _storage.delete(key: '$_defaultStartHeightPrefix$walletName');
  }
}
