import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_libepiccash_example/transaction_view.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'epicbox_config.dart';

class RecoverWalletView extends StatelessWidget {
  RecoverWalletView({Key? key, required this.name}) : super(key: key);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Wallet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: EpicRecoverWalletView(title: 'Recover from mnemonic', name: name),
    );
  }
}

class EpicRecoverWalletView extends StatefulWidget {
  const EpicRecoverWalletView(
      {Key? key, required this.title, required this.name})
      : super(key: key);

  final String name;
  final String title;

  @override
  State<EpicRecoverWalletView> createState() => _EpicRecoverWalletView();
}

class _EpicRecoverWalletView extends State<EpicRecoverWalletView> {
  String mnemonic = "";
  String password = "";
  String walletConfig = "";
  String recoverError = "";
  final storage = new FlutterSecureStorage();

  String walletDirectory = "";
  Future<String> createFolder(String folderName) async {
    Directory appDocDir = (await getApplicationDocumentsDirectory());
    if (Platform.isIOS) {
      appDocDir = (await getLibraryDirectory());
    }
    String appDocPath = appDocDir.path;
    print("Doc path is $appDocPath");

    Directory _appDocDir = (await getApplicationDocumentsDirectory());
    if (Platform.isIOS) {
      _appDocDir = (await getLibraryDirectory());
    }
    final Directory _appDocDirFolder =
        Directory('${_appDocDir.path}/$folderName/');

    if (await _appDocDirFolder.exists()) {
      //if folder already exists return path
      return "directory_exists";
    } else {
      //if folder not exists create folder and then return its path
      final Directory _appDocDirNewFolder =
          await _appDocDirFolder.create(recursive: true);

      setState(() {
        walletDirectory = _appDocDirNewFolder.path;
      });
      return _appDocDirNewFolder.path;
    }
  }

  Future<String> _getWalletConfig(String name) async {
    return await EpicboxConfig.getDefaultConfig(name);
  }

  bool _createWalletFolder(name) {
    // String nameToLower = name.
    createFolder(name.toLowerCase()).then((value) {
      if (value == "directory_exists") {
        return false;
      }
    });
    return true;
  }

  String _recoverWallet(
    String configPtr,
    String passwordPtr,
    String mnemonicPtr,
    String namePtr,
  ) {
    final String recoverWalletStr =
        recoverWallet(configPtr, passwordPtr, mnemonicPtr, namePtr);
    return recoverWalletStr;
  }

  void _setMnemonic(value) {
    mnemonic = mnemonic + value;
  }

  void _setPassword(value) {
    print("Set password");
    setState(() {
      password = password + value;
    });
  }

  void _setRecoverError(value) {
    setState(() {
      recoverError = value;
    });
  }

  Future<void> _storeConfig(config) async {
    await storage.write(key: "config", value: config);
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    String name = widget.name;
    _createWalletFolder(name);

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              Text(recoverError),
              TextFormField(
                decoration: InputDecoration(hintText: name),
                enabled: false,
              ),
              TextFormField(
                decoration: InputDecoration(hintText: "Recovery string"),
                maxLines: 10,
                // The validator receives the text that the user has entered.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter wallet phrase';
                  }
                  _setMnemonic(value);
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(hintText: "Wallet Password"),
                // The validator receives the text that the user has entered.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter wallet password';
                  }
                  _setPassword(value);
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    String walletConfig = await _getWalletConfig(name);

                    String recover =
                        recoverWallet(walletConfig, password, mnemonic, name);

                    if (recover == "recovered") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TransactionView(
                                  password: password,
                                  walletName: name,
                                )),
                      );
                    } else {
                      _setRecoverError(recover);
                    }
                  }
                },
                child: const Text('Next'),
              ),
              // Add TextFormFields and ElevatedButton here.
            ],
          ),
        ));
  }
}
