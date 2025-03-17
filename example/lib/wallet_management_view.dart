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

class _WalletManagementViewState extends State<WalletManagementView>
    with WidgetsBindingObserver {
  final List<String> _wallets = [];
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshWallets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshWallets();
  }

  @override
  void didPopNext() {
    _refreshWallets();
  }

  Future<List<String>> _getWalletDirectories() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      final walletsDir =
          Directory('${appDir.path}/flutter_libepiccash/example/wallets');
      if (!await walletsDir.exists()) {
        await walletsDir.create(recursive: true);
      }

      final walletDirs = walletsDir.listSync().whereType<Directory>();
      return walletDirs.map((dir) => dir.path.split('/').last).toList();
    } catch (e) {
      print("Error reading wallet directories: $e");
      return [];
    }
  }

  Future<void> _refreshWallets() async {
    print("Refreshing wallet list");
    final wallets = await _getWalletDirectories();
    if (mounted) {
      setState(() {
        _wallets.clear();
        _wallets.addAll(wallets);
      });
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
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                WalletInfoView(walletName: walletName, password: result)),
      );
      _refreshWallets();
    }
  }

  Future<bool> _forceDeleteWalletDirectory(String walletName) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      final walletDir = Directory(
          '${appDir.path}/flutter_libepiccash/example/wallets/$walletName');
      if (await walletDir.exists()) {
        await walletDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      print("Error force deleting wallet directory: $e");
      return false;
    }
  }

  Future<bool> _deleteWallet(String walletName,
      {bool forceDelete = false}) async {
    try {
      setState(() {
        _isDeleting = true;
      });

      if (forceDelete) {
        return await _forceDeleteWalletDirectory(walletName);
      }

      String config = await EpicboxConfig.getDefaultConfig(walletName);
      String result = await deleteWallet(walletName, config);

      if (result == "deleted") {
        await _forceDeleteWalletDirectory(walletName);
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete wallet "$walletName"?'),
              const SizedBox(height: 16),
              const Text(
                'Warning: Force delete will remove the wallet directory even if the wallet is corrupted.',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            TextButton(
              child: const Text('Force Delete',
                  style: TextStyle(color: Colors.orange)),
              onPressed: () => Navigator.of(context).pop({
                'confirmed': true,
                'force': true,
              }),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop({
                'confirmed': true,
                'force': false,
              }),
            ),
          ],
        );
      },
    );

    if (result != null && result['confirmed']) {
      final success =
          await _deleteWallet(walletName, forceDelete: result['force']);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wallet "$walletName" deleted successfully')),
        );
        _refreshWallets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete wallet. Try using Force Delete.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshWallets,
          ),
        ],
      ),
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
                            onTap: () async {
                              await _promptPasswordAndNavigate(
                                  context, _wallets[index]);
                              _refreshWallets();
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
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const WalletNameView(recover: false),
                    ),
                  );
                  _refreshWallets();
                },
                child: const Text('Create Wallet'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WalletNameView(recover: true),
                    ),
                  );
                  _refreshWallets();
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
