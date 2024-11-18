import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'transaction_view.dart';
import 'wallet_name.dart';

class WalletManagementView extends StatefulWidget {
  const WalletManagementView({Key? key}) : super(key: key);

  @override
  State<WalletManagementView> createState() => _WalletManagementViewState();
}

class _WalletManagementViewState extends State<WalletManagementView> {
  final List<String> _wallets = [];

  Future<List<String>> _getWalletDirectories() async {
    try {
      // Get the application documents directory.
      Directory appDir = await getApplicationDocumentsDirectory();
      // Create a "wallets" folder if it does not exist.
      final walletsDir =
          Directory('${appDir.path}/flutter_libepiccash/example/wallets');
      if (!await walletsDir.exists()) {
        await walletsDir.create(recursive: true);
      }

      // Verify if wallet directories are stored under "wallets" folder.
      final walletDirs = walletsDir.listSync().whereType<Directory>();
      return walletDirs.map((dir) => dir.path.split('/').last).toList();
    } catch (e) {
      print("Error reading wallet directories: $e");
      return [];
    }
  }

  Future<void> _refreshWallets() async {
    final wallets = await _getWalletDirectories();
    setState(() {
      _wallets.clear();
      _wallets.addAll(wallets);
    });
  }

  Future<void> _promptPasswordAndNavigate(
      BuildContext context, String walletName) async {
    final TextEditingController _passwordController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Password'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Password'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context, null);
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.pop(context, _passwordController.text);
              },
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Navigate to TransactionView with the wallet name and entered password
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionView(
            walletName: walletName,
            password: result,
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshWallets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Wallets')),
      body: Column(
        children: [
          Expanded(
            child: _wallets.isEmpty
                ? const Center(child: Text("No wallets found."))
                : ListView.builder(
                    itemCount: _wallets.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_wallets[index]),
                        onTap: () {
                          _promptPasswordAndNavigate(context, _wallets[index]);
                        },
                      );
                    },
                  ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WalletNameView(recover: false),
                ),
              ).then((_) => _refreshWallets());
            },
            child: const Text('Create Wallet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WalletNameView(recover: true),
                ),
              ).then((_) => _refreshWallets());
            },
            child: const Text('Recover Wallet'),
          ),
        ],
      ),
    );
  }
}
