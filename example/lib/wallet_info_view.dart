import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/lib.dart';
import 'package:flutter_libepiccash_example/transaction_view.dart';

import 'epicbox_config.dart';

class WalletInfoView extends StatelessWidget {
  final String walletName;
  final String password;

  const WalletInfoView({
    Key? key,
    required this.walletName,
    required this.password,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      // 1) Load the config from EpicboxConfig
      future: EpicboxConfig.getDefaultConfig(walletName),
      builder: (context, configSnapshot) {
        if (configSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (configSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error loading config: ${configSnapshot.error}'),
            ),
          );
        }

        final config = configSnapshot.data!;

        // 2) Next, open the wallet
        return FutureBuilder<String>(
          future: LibEpiccash.openWallet(config: config, password: password),
          builder: (context, openWalletSnapshot) {
            if (openWalletSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (openWalletSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child:
                      Text('Error opening wallet: ${openWalletSnapshot.error}'),
                ),
              );
            }

            final walletPointer = openWalletSnapshot.data!;

            // 3) Fetch address information from the newly opened wallet.
            //    Replace {} with a real epicbox config if needed.
            return FutureBuilder<String>(
              future: LibEpiccash.getAddressInfo(
                wallet: walletPointer,
                epicboxConfig: config,
                index: 0, // In practice we only use index 0.
              ),
              builder: (context, addressSnapshot) {
                if (addressSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (addressSnapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text(
                          'Error fetching address: ${addressSnapshot.error}'),
                    ),
                  );
                }

                final address = addressSnapshot.data ?? '(No address found)';

                // 4) Display your info here.
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Wallet Info'),
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Wallet Name: $walletName',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Epicbox Address: $address',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TransactionView(
                                  walletName: walletName,
                                  password: password,
                                ),
                              ),
                            );
                          },
                          child: const Text('View Transactions'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
