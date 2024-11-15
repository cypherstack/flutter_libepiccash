import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/lib.dart';

import 'transaction_view.dart';

class MnemonicView extends StatelessWidget {
  final String name;
  final String password;

  MnemonicView({Key? key, required this.name, required this.password})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Mnemonic'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<String>(
        future: Future.value(LibEpiccash.getMnemonic()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final mnemonic = snapshot.data!;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(mnemonic),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await LibEpiccash.initializeNewWallet(
                        config: 'real-config', // Replace with actual config
                        mnemonic: mnemonic,
                        password: password,
                        name: name,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionView(
                            walletName: name,
                            password: password,
                          ),
                        ),
                      );
                    } catch (e) {
                      print('Error creating wallet: $e');
                    }
                  },
                  child: const Text('Create Wallet'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
