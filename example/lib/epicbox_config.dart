import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class EpicboxConfig {
  /// Returns the default Epicbox configuration as a JSON-encoded string.
  static Future<String> getDefaultConfig(String walletName) async {
    // Get the application documents directory
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String walletDir = '${appDocDir.path}/flutter_libepiccash/$walletName';

    // Construct the configuration
    var config = {
      "wallet_dir": walletDir,
      "check_node_api_http_addr": "http://epiccash.stackwallet.com:3413",
      "chain": "mainnet",
      "account": "default",
      "api_listen_port": 3413,
      "api_listen_interface": "epiccash.stackwallet.com",
    };

    return json.encode(config);
  }
}
