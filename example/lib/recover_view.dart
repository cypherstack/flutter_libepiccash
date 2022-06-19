import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_libepiccash_example/transaction_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RecoverWalletView extends StatelessWidget {
  RecoverWalletView({Key? key, required this.name}) : super(key: key);
  final String name;
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet Name',
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
      home: EpicRecoverWalletView(title: 'Recover from mnemonic', name: name),
    );
  }
}

class EpicRecoverWalletView extends StatefulWidget {
  const EpicRecoverWalletView(
      {Key? key, required this.title, required this.name})
      : super(key: key);

  final String name;
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<EpicRecoverWalletView> createState() => _EpicRecoverWalletView();
}

class _EpicRecoverWalletView extends State<EpicRecoverWalletView> {
  String mnemonic = "";
  String password = "";
  String walletConfig = "";
  final storage = new FlutterSecureStorage();

  String walletDirectory = "";
  Future<String> createFolder(String folderName) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
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

  String _getWalletConfig(name) {
    var config = {};
    config["wallet_dir"] =
        "/data/user/0/com.example.flutter_libepiccash_example/app_flutter/$name/";
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

  String _recoverWallet(Pointer<Utf8> configPtr, Pointer<Utf8> passwordPtr,
      Pointer<Utf8> mnemonicPtr) {
    final Pointer<Utf8> recoverWalletPtr =
        recoverWallet(configPtr, passwordPtr, mnemonicPtr);
    final String recoverWalletStr = recoverWalletPtr.toDartString();
    print("Wallet recover is : $recoverWalletStr");
    return recoverWalletStr;
    // print("Wallet info now is : $walletInfoStr");
    // final Pointer<Utf8> recoverWalletPtr =
    //     recoverWallet(config, password, mnemonic);
    // final String recoverWalletStr = recoverWalletPtr.toDartString();
    // return recoverWalletStr;
  }

  void _setMnemonic(value) {
    print("Set Mnemonic");
    print(value);
    // setState(() {
    mnemonic = mnemonic + value;
    // });
  }

  void _setPassword(value) {
    print("Set password");
    setState(() {
      password = password + value;
    });
  }

  Future<void> _storeConfig(config) async {
    await storage.write(key: "config", value: config);
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    String name = widget.name;
    bool walletFolder = _createWalletFolder(name);

    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
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
                onPressed: () {
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    String walletMnemonic = mnemonic;
                    String walletPassword = password;
                    String walletConfig = _getWalletConfig(name);

                    // String strConf = json.encode(walletConfig);
                    final Pointer<Utf8> configPointer =
                        walletConfig.toNativeUtf8();
                    final Pointer<Utf8> mnemonicPtr =
                        walletMnemonic.toNativeUtf8();
                    final Pointer<Utf8> passwordPtr =
                        walletPassword.toNativeUtf8();

                    print(walletConfig);
                    print(password);
                    print(mnemonic);
                    _recoverWallet(configPointer, passwordPtr, mnemonicPtr);
                    //Store config and password in secure storage since we will need them again
                    // _storeConfig(walletConfig);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TransactionView(
                                password: password,
                              )),
                    );
                  }
                },
                child: const Text('Next'),
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
  }
}
