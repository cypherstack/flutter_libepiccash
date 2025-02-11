import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_libepiccash_example/wallet_info_view.dart';
import 'package:path_provider/path_provider.dart';

import 'epicbox_config.dart';
import 'wallet_name.dart';

class WalletManagementView extends StatefulWidget {
  const WalletManagementView({Key? key}) : super(key: key);

  @override
  State<WalletManagementView> createState() => _WalletManagementViewState();
}

class _WalletManagementViewState extends State<WalletManagementView> {
  final List<String> _wallets = [];
  bool _isDeleting = false;

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

  Future<bool> _deleteWallet(String walletName) async {
    try {
      setState(() {
        _isDeleting = true;
      });

      // Get the wallet config.
      String config = await EpicboxConfig.getDefaultConfig(walletName);

      // Call the delete wallet function.
      String result = await deleteWallet(walletName, config);

      if (result == "deleted") {
        // Delete the wallet directory.
        Directory appDir = await getApplicationDocumentsDirectory();
        final walletDir = Directory(
            '${appDir.path}/flutter_libepiccash/example/wallets/$walletName');
        if (await walletDir.exists()) {
          await walletDir.delete(recursive: true);
        }
        return true;
      }
      return false;
    } catch (e) {
      print("Error deleting wallet: $e");
      return false;
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, String walletName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Wallet'),
          content: Text(
              'Are you sure you want to delete wallet "$walletName"?\n\nThis action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final success = await _deleteWallet(walletName);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wallet "$walletName" deleted successfully')),
        );
        _refreshWallets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete wallet "$walletName"')),
        );
      }
    }
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
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                WalletInfoView(walletName: walletName, password: result)),
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
      body: Stack(
        children: [
          Column(
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
                              _promptPasswordAndNavigate(
                                  context, _wallets[index]);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmation(
                                  context, _wallets[index]),
                            ),
                          );
                        },
                      ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const WalletNameView(recover: false),
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
          if (_isDeleting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
