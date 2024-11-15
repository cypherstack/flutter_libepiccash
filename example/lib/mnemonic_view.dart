import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_libepiccash_example/transaction_view.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'epicbox_config.dart';

class MnemonicView extends StatelessWidget {
  MnemonicView({Key? key, required this.name, required this.password})
      : super(key: key);

  final String name;
  final String password;

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
      body: EpicMnemonicView(
        title: 'Wallet Recovery Phrase',
        name: name,
        password: password,
      ),
    );
  }
}

class EpicMnemonicView extends StatefulWidget {
  final String name;
  final String password;

  const EpicMnemonicView(
      {Key? key,
      required this.title,
      required this.name,
      required this.password})
      : super(key: key);

  final String title;

  @override
  State<EpicMnemonicView> createState() => _EpicMnemonicView();
}

class _EpicMnemonicView extends State<EpicMnemonicView> {
  var mnemonic = "";
  var walletConfig = "";
  final storage = new FlutterSecureStorage();

  String walletDirectory = "";

  Future<String> createFolder(String folderName) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    print("App Document Directory Path: $appDocPath");

    final Directory folderDir = Directory('${appDocDir.path}/$folderName');

    if (await folderDir.exists()) {
      return "directory_exists";
    } else {
      try {
        final Directory newFolder = await folderDir.create(recursive: true);
        return newFolder.path;
      } catch (e) {
        print("Error creating folder: $e");
        return "error";
      }
    }
  }

  Future<String> _getWalletConfig(String name) async {
    return await EpicboxConfig.getDefaultConfig(name);
  }

  bool _createWalletFolder(String name) {
    createFolder(name.toLowerCase()).then((value) {
      if (value == "error") {
        print("Failed to create wallet directory. Check permissions.");
      } else if (value == "directory_exists") {
        print("Wallet directory already exists.");
      } else {
        print("Wallet directory created at: $value");
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    walletMnemonic();
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Text("$mnemonic"),
              ElevatedButton(
                onPressed: () async {
                  bool walletFolder = _createWalletFolder(widget.name);

                  if (walletFolder) {
                    String walletConfig = await _getWalletConfig(widget.name);

                    mnemonic = walletMnemonic();
                    initWallet(
                        walletConfig, mnemonic, widget.password, widget.name);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TransactionView(
                                password: widget.password,
                                walletName: widget.name,
                              )),
                    );
                  }
                },
                child: const Text('Create Wallet'),
              ),
              // Add TextFormFields and ElevatedButton here.
            ],
          ),
        ));
  }
}
