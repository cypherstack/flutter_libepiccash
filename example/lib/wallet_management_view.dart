import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'init_transaction_view.dart';
import 'mnemonic_view.dart';
import 'recover_view.dart';
import 'transaction_view.dart';

class WalletManagementView extends StatefulWidget {
  const WalletManagementView({Key? key}) : super(key: key);

  @override
  State<WalletManagementView> createState() => _WalletManagementViewState();
}

class _WalletManagementViewState extends State<WalletManagementView> {
  List<String> wallets = [];
  String? selectedWallet;

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory walletDir = Directory('${appDocDir.path}/wallets');
      if (!await walletDir.exists()) {
        await walletDir.create(recursive: true);
      }
      setState(() {
        wallets = walletDir
            .listSync()
            .where((entity) => entity is Directory)
            .map((entity) => entity.path.split('/').last)
            .toList();
      });
    } catch (e) {
      print("Error loading wallets: $e");
    }
  }

  void _setSelectedWallet(String wallet) {
    setState(() {
      selectedWallet = wallet;
    });
  }

  void _createWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MnemonicView(
          name: '',
          password:
              '', // Handle password directly within the wallet creation flow.
        ),
      ),
    ).then((_) => _loadWallets());
  }

  void _recoverWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecoverWalletView(
          name: '',
        ),
      ),
    ).then((_) => _loadWallets());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Management')),
      body: Column(
        children: [
          ListTile(
            title: const Text('Available Wallets'),
            subtitle: Text(wallets.isEmpty
                ? 'No wallets found. Create or recover a wallet to get started.'
                : '${wallets.length} wallet(s) available.'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: wallets.length,
              itemBuilder: (context, index) {
                final wallet = wallets[index];
                return ListTile(
                  title: Text(wallet),
                  trailing: selectedWallet == wallet
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () => _setSelectedWallet(wallet),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Actions'),
          ),
          ElevatedButton(
            onPressed: _createWallet,
            child: const Text('Create New Wallet'),
          ),
          ElevatedButton(
            onPressed: _recoverWallet,
            child: const Text('Recover Wallet'),
          ),
          ElevatedButton(
            onPressed: selectedWallet != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionView(
                          walletName: selectedWallet!,
                          password:
                              '', // Assume password handling within views.
                        ),
                      ),
                    );
                  }
                : null,
            child: const Text('View Transactions'),
          ),
          ElevatedButton(
            onPressed: selectedWallet != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InitTransactionView(
                          password:
                              '', // Assume password handling within views.
                        ),
                      ),
                    );
                  }
                : null,
            child: const Text('Initiate Transaction'),
          ),
        ],
      ),
    );
  }
}
