import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_libepiccash_example/transaction_view.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<EpicMnemonicView> createState() => _EpicMnemonicView();
}

class _EpicMnemonicView extends State<EpicMnemonicView> {
  var mnemonic = "";
  var walletConfig = "";
  final storage = new FlutterSecureStorage();

  // void _getMnemonic() {
  //   final String mnemonicString = walletMnemonic();
  //
  //   setState(() {
  //     mnemonic = mnemonicString;
  //   });
  // }

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
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String walletDir = '${appDocDir.path}/flutter_libepiccash/$name';

    var config = {
      "wallet_dir": walletDir,
      "check_node_api_http_addr": "http://95.216.215.107:3413",
      "chain": "mainnet",
      "account": "default",
      "api_listen_port": 3413,
      "api_listen_interface": "0.0.0.0"
    };

    print("Wallet config: $config");

    return json.encode(config);
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

  Future<void> _storeConfig(config) async {
    await storage.write(key: "config", value: config);
  }

  final _formKey = GlobalKey<FormState>();
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
                  // _createWalletFolder(widget.name);
                  print(widget.name);
                  print(widget.password);
                  bool walletFolder = _createWalletFolder(widget.name);

                  if (walletFolder == true) {
                    //Create wallet

                    String walletName = widget.name;
                    String walletPassword = widget.password;
                    String walletConfig = await _getWalletConfig(walletName);

                    // String strConf = json.encode(walletConfig);
                    //Store config and password in secure storage since we will need them again
                    _storeConfig(walletConfig);
                    mnemonic = walletMnemonic();
                    initWallet(
                        walletConfig, mnemonic, walletPassword, walletName);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TransactionView(
                                password: widget.password,
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
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            // The validator receives the text that the user has entered.
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter some text';
              }
              return null;
            },
          ),
          ElevatedButton(
            onPressed: () {
              // Validate returns true if the form is valid, or false otherwise.
              if (_formKey.currentState!.validate()) {
                // If the form is valid, display a snackbar. In the real world,
                // you'd often call a server or save the information in a database.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Processing Data')),
                );
              }
            },
            child: const Text('Submit'),
          ),
          // Add TextFormFields and ElevatedButton here.
        ],
      ),
    );
  }
}
