import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/flutter_libepiccash.dart';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TransactionView extends StatelessWidget {
  TransactionView({Key? key, required this.password}) : super(key: key);

  final String password;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet Transactions',
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
      home: EpicTransactionView(
        title: 'Transactions',
        password: password,
      ),
    );
  }
}

class EpicTransactionView extends StatefulWidget {
  final String password;

  const EpicTransactionView(
      {Key? key, required this.title, required this.password})
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
  State<EpicTransactionView> createState() => _EpicTransactionView();
}

class _EpicTransactionView extends State<EpicTransactionView> {
  String walletConfig = "";
  final storage = new FlutterSecureStorage();

  Future<void> _getWalletConfig() async {
    var config = await storage.read(key: "config");
    String strConf = json.encode(config);

    setState(() {
      walletConfig = strConf;
    });
  }

  String _scanWallet(Pointer<Utf8> config, Pointer<Utf8> password) {
    final Pointer<Utf8> scanOutputsPtr = scanOutPuts(config, password);
    final String scanOutputsStr = scanOutputsPtr.toDartString();
    return scanOutputsStr;
  }

  String _getWalletInfo(Pointer<Utf8> config, Pointer<Utf8> password) {
    final Pointer<Utf8> walletInfoPtr = walletInfo(config, password);
    final String walletInfoStr = walletInfoPtr.toDartString();
    return walletInfoStr;
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    _getWalletConfig();
    String password = widget.password;

    print("Wallet Config");
    print(json.decode(walletConfig));
    String decodeConfig = json.decode(walletConfig);

    final Pointer<Utf8> configPointer = decodeConfig.toNativeUtf8();
    final Pointer<Utf8> passwordPtr = password.toNativeUtf8();

    String walletInfo = _getWalletInfo(configPointer, passwordPtr);
    var data = json.decode(walletInfo);

    var total = data['total'].toString();
    var awaitingFinalisation = data['amount_awaiting_finalization'].toString();
    var awaitingConfirmation = data['amount_awaiting_confirmation'].toString();
    var spendable = data['amount_currently_spendable'].toString();
    var locked = data['amount_locked'].toString();
    // List  = walletInfo;

    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Text("Total Amount : $total"),
              Text("Amount Awaiting Finalization : $awaitingFinalisation"),
              Text("Amount Awaiting Confirmation : $awaitingConfirmation"),
              Text("Amount Currently Spendable : $spendable"),
              Text("Amount Locked : $locked"),
              // ElevatedButton(
              //   onPressed: () {
              //     // _createWalletFolder(widget.name);
              //     print(widget.name);
              //     print(widget.password);
              //     bool walletFolder = _createWalletFolder(widget.name);
              //
              //     if (walletFolder == true) {
              //       //Create wallet
              //
              //       String walletName = widget.name;
              //       String walletPassword = widget.password;
              //       String walletConfig = _getWalletConfig(walletName);
              //
              //       // String strConf = json.encode(walletConfig);
              //       final Pointer<Utf8> configPointer =
              //           walletConfig.toNativeUtf8();
              //       final Pointer<Utf8> mnemonicPtr = mnemonic.toNativeUtf8();
              //       final Pointer<Utf8> namePtr = walletName.toNativeUtf8();
              //       final Pointer<Utf8> passwordPtr =
              //           walletPassword.toNativeUtf8();
              //       //Store config and password in secure storage since we will need them again
              //       _storeConfig(walletConfig);
              //       _createWallet(
              //           configPointer, mnemonicPtr, passwordPtr, namePtr);
              //       // Navigator.push(
              //       //   context,
              //       //   MaterialPageRoute(
              //       //       builder: (context) => BalancesView(
              //       //         passwotd: widget.password,
              //       //       )),
              //       // );
              //     }
              //
              //     // _createWalletFolder(widget.name);
              //     // print(foldername);
              //     // _createWallet(widget.name, widget.password, mnemonic);
              //     // Validate returns true if the form is valid, or false otherwise.
              //     // Navigator.push(
              //     //   context,
              //     //   MaterialPageRoute(
              //     //       builder: (context) => PasswordView(
              //     //         name: name,
              //     //       )),
              //     // );
              //   },
              //   child: const Text('Create Wallet'),
              // ),
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
