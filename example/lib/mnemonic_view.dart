import 'dart:ffi';
import 'dart:io';

import 'package:flutter_libepiccash_example/main.dart';
import 'package:flutter_libepiccash_example/password_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/flutter_libepiccash.dart';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_libepiccash_example/transaction_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MnemonicView extends StatelessWidget {
  MnemonicView({Key? key, required this.name, required this.password})
      : super(key: key);

  final String name;
  final String password;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet mnemonic',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: EpicMnemonicView(
        title: 'Wallet Recovery phrase',
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
    Directory appDocDir = (await getApplicationDocumentsDirectory());
    if (Platform.isIOS) {
      appDocDir = (await getLibraryDirectory());
    }
    String appDocPath = appDocDir.path;
    print("Doc path is $appDocPath");

    final Directory _appDocDir = await getApplicationDocumentsDirectory();
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

  Future<String> _getWalletConfig(name) async {
    var config = {};
    // TODO: make robust path finder for IOS and Android
    // although getApplicationDocumentsDirectory should be enough for both.
    if (Platform.isIOS) {
      config["wallet_dir"] =
          "${(await getLibraryDirectory()).path}/epiccash/$name/";
      print("wallet dir ${config["wallet_dir"]}");
    } else {
      config["wallet_dir"] =
          "/data/user/0/com.example.flutter_libepiccash_example/app_flutter/$name/";
    }
    config["check_node_api_http_addr"] = "http://95.216.215.107:3413";
    config["chain"] = "mainnet";
    config["account"] = "default";
    config["api_listen_port"] = 3413;
    config["api_listen_interface"] = "95.216.215.107";

    String strConf = json.encode(config);
    return strConf;
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

  Future<void> _storeConfig(config) async {
    await storage.write(key: "config", value: config);
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    walletMnemonic();
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
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
