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
    rust_open_wallet("const char *config",
                     "const char *password");
    rust_wallet_balances("const char *wallet", "const char *refresh", "const char *min_confirmations");
    rust_recover_from_mnemonic("const char *config",
                               "const char *password",
                               "const char *mnemonic",
                               "const char *name");

    rust_wallet_scan_outputs("const char *wallet",
                             "const char *start_height", "onst char *number_of_blocks");

    rust_create_tx("const char *wallet",
                   "const char *amount",
                   "const char *to_address",
                   "const char *secret_key_index", "const char *epicbox_config", "const char *min_confirmations");
    rust_txs_get("const char *wallet",
                 "const char *refresh_from_node");
    rust_tx_cancel("const char *wallet", "const char *tx_id");

    rust_get_chain_height("const char *config");
    rust_delete_wallet("const char *wallet",
                       "const char *epicbox_config");
    rust_get_wallet_address("const char *wallet", "const char *index", "const char *epicbox_config");
    rust_validate_address("const char *address");
    rust_get_tx_fees("const char *wallet", "const char *c_amount", "const char *min_confirmations");

    rust_tx_send_http("const char *wallet", "const char *selection_strategy_is_use_all","const char *minimum_confirmations",
                      "const char *message",
                      "const char *amount",
                      "const char *address")

    run_listener("const char *wallet",
                 "const char *epicbox_config");
      // ...
      // This code will force the bundler to use these functions, but will never be called
    }
}
