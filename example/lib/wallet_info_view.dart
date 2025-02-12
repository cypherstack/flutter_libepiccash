import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_libepiccash_example/advanced_functions_view.dart';
import 'package:flutter_libepiccash_example/init_transaction_view.dart';

import 'epicbox_config.dart';

class WalletInfoView extends StatelessWidget {
  final String walletName;
  final String password;

  const WalletInfoView({
    Key? key,
    required this.walletName,
    required this.password,
  }) : super(key: key);

  Future<String> _getWalletAddress(String config) async {
    try {
      // Open wallet.
      final walletResult = openWallet(config, password);
      if (walletResult.contains('Error')) {
        return 'Error opening wallet: $walletResult';
      }

      final epicboxConfig = await EpicboxConfig.getDefaultConfig(walletName);
      // Get address using index 0 (the only index used in practice.
      final address = getAddressInfo(walletResult, 0, epicboxConfig);
      return address;
    } catch (e) {
      return 'Error getting address: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Wallet: $walletName'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
        body: FutureBuilder<String>(
          future: EpicboxConfig.getDefaultConfig(walletName),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final config = snapshot.data!;
            return FutureBuilder<String>(
              future: _getWalletAddress(config),
              builder: (context, addressSnapshot) {
                if (addressSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet Address:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                addressSnapshot.data ?? 'Error getting address',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                  text: addressSnapshot.data ?? '',
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Address copied to clipboard'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        InitTransactionView(password: password),
                                  ),
                                );
                              },
                              child: const Text('Initiate Transaction'),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdvancedFunctionsView(),
                                  ),
                                );
                              },
                              child: const Text('Advanced Functions'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
