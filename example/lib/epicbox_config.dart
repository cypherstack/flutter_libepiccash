import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class EpicboxConfig {
  /// Returns the default Epicbox configuration as a JSON-encoded string.
  static Future<String> getDefaultConfig(String walletName) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String walletDir = '${appDocDir.path}/flutter_libepiccash/$walletName';

    var config = {
      "wallet_dir": walletDir,
      // "/data/user/0/com.example.flutter_libepiccash_example/app_flutter/$name/"
      // has been used in the past.
      "check_node_api_http_addr": "http://epiccash.stackwallet.com:3413",
      "chain": "mainnet",
      "account": "default",
      "api_listen_port": 3413,
      "api_listen_interface": "epiccash.stackwallet.com",
      // Lower-level docs refer to using 0.0.0.0 "to receive epics" [sp] (?),
      // search globally for 0.0.0.0 to see for yourself.
    };

    return json.encode(config);
  }
}
