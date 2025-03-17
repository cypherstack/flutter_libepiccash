import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash_example/mnemonic_view.dart';
import 'package:flutter_libepiccash_example/recover_view.dart';
import 'package:flutter_libepiccash_example/util.dart';
import 'package:path_provider/path_provider.dart';

class WalletNameView extends StatelessWidget {
  const WalletNameView({Key? key, required this.recover}) : super(key: key);
  final bool recover;

  Future<void> _cleanupWalletDirectory(String walletName) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      final walletDir = Directory(
          '${appDir.path}/flutter_libepiccash/example/wallets/$walletName');
      if (await walletDir.exists()) {
        await walletDir.delete(recursive: true);
      }
    } catch (e) {
      print("Error cleaning up wallet directory: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController _controller = TextEditingController();

    return WillPopScope(
      onWillPop: () async {
        if (_controller.text.isNotEmpty) {
          await _cleanupWalletDirectory(_controller.text);
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(recover ? 'Recover Wallet' : 'Create Wallet'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_controller.text.isNotEmpty) {
                await _cleanupWalletDirectory(_controller.text);
              }
              Navigator.pop(context);
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Wallet Name'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_controller.text.isNotEmpty) {
                    final walletPath = await createFolder(_controller.text);
                    if (walletPath == "directory_exists" ||
                        walletPath != "error") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => recover
                              ? RecoverWalletView(name: _controller.text)
                              : MnemonicView(
                                  name: _controller.text,
                                  // onCancel: () async {
                                  //   await _cleanupWalletDirectory(_controller.text);
                                  //   Navigator.pop(context);
                                  //   Navigator.pop(context);
                                  // },
                                ),
                        ),
                      );
                    } else {
                      print("Error: Wallet directory could not be created.");
                    }
                  }
                },
                child: Text(recover ? 'Next' : 'Create'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
