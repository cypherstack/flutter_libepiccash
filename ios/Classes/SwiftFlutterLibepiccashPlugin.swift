import Flutter
import UIKit

public class SwiftFlutterLibepiccashPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_libepiccash", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterLibepiccashPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }

// TODO whenever epic cash is updated with new functions, they need to be dummy called here.
    public func dummyMethodToEnforceBundling() {
    wallet_init("const char *config",
                        "const char *mnemonic",
                        "const char *password",
                        "const char *name");
    get_mnemonic();
    rust_wallet_balances("const char *config", "const char *password", "const char *refresh");
    rust_recover_from_mnemonic("const char *config",
                                       "const char *password",
                                       "const char *mnemonic",
                                       "const char *name");
    rust_wallet_phrase("const char *config", "const char *password");
    rust_wallet_scan_outputs("const char *config",
                                     "const char *password",
                                     "const char *start_height");
    rust_create_tx("const char *config",
                           "const char *password",
                           "const char *amount",
                           "const char *to_address",
                           "const char *sender_key");
    rust_txs_get("const char *config",
                         "const char *password",
                         "const char *minimum_confirmations",
                         "const char *refresh_from_node");
    rust_tx_cancel("const char *config", "const char *password", "const char *tx_id");
    rust_check_for_new_slates("const char *receiver_key");
    rust_process_pending_slates("const char *config",
                                        "const char *password",
                                        "const char *receiver_key",
                                        "const char *slates");
    rust_tx_receive("const char *config", "const char *password", "const char *slate");
    rust_get_chain_height("const char *config");
    rust_get_address_and_keys();
    rust_validate_address("const char *address");
    rust_get_tx_fees("const char *c_config", "const char *c_password", "const char *c_amount");

      // ...
      // This code will force the bundler to use these functions, but will never be called
    }
}
