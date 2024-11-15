import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AdvancedFunctionsView extends StatelessWidget {
  const AdvancedFunctionsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Wallet Functions',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AdvancedFunctionsHome(title: 'Advanced Functions'),
    );
  }
}

class AdvancedFunctionsHome extends StatefulWidget {
  const AdvancedFunctionsHome({Key? key, required this.title})
      : super(key: key);

  final String title;

  @override
  State<AdvancedFunctionsHome> createState() => _AdvancedFunctionsHomeState();
}

class _AdvancedFunctionsHomeState extends State<AdvancedFunctionsHome> {
  final storage = const FlutterSecureStorage();
  String walletConfig = "";
  String resultMessage = "Perform actions to see results here.";

  Future<void> _loadWalletConfig() async {
    try {
      var config = await storage.read(key: "config");
      if (config != null && config.isNotEmpty) {
        setState(() {
          walletConfig = config;
        });
      } else {
        setState(() {
          resultMessage = "No wallet configuration found.";
        });
      }
    } catch (e) {
      setState(() {
        resultMessage = "Error loading wallet config: $e";
      });
    }
  }

  Future<void> _getAddressInfo() async {
    try {
      String addressInfo = getAddressInfo(walletConfig, 0, "{}");
      setState(() {
        resultMessage = "Address Info: $addressInfo";
      });
    } catch (e) {
      setState(() {
        resultMessage = "Error retrieving address info: $e";
      });
    }
  }

  Future<void> _getChainHeight() async {
    try {
      int height = getChainHeight(walletConfig);
      setState(() {
        resultMessage = "Chain Height: $height";
      });
    } catch (e) {
      setState(() {
        resultMessage = "Error retrieving chain height: $e";
      });
    }
  }

  Future<void> _scanOutputs() async {
    try {
      String result = await scanOutPuts(walletConfig, 0, 100);
      setState(() {
        resultMessage = "Scan Outputs Result: $result";
      });
    } catch (e) {
      setState(() {
        resultMessage = "Error scanning outputs: $e";
      });
    }
  }

  Future<void> _deleteWallet() async {
    try {
      String result = await deleteWallet("example", walletConfig);
      setState(() {
        resultMessage = "Delete Wallet Result: $result";
      });
    } catch (e) {
      setState(() {
        resultMessage = "Error deleting wallet: $e";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWalletConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Text(
              "Wallet Config Loaded: ${walletConfig.isNotEmpty ? 'Yes' : 'No'}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _getAddressInfo,
              child: const Text("Get Address Info"),
            ),
            ElevatedButton(
              onPressed: _getChainHeight,
              child: const Text("Get Chain Height"),
            ),
            ElevatedButton(
              onPressed: _scanOutputs,
              child: const Text("Scan Outputs"),
            ),
            ElevatedButton(
              onPressed: _deleteWallet,
              child: const Text("Delete Wallet"),
            ),
            const SizedBox(height: 20),
            Text(
              resultMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
