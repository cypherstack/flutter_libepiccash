import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:ffi/ffi.dart';

class InitTransactionView extends StatelessWidget {
  const InitTransactionView({Key? key, required this.password})
      : super(key: key);
  final String password;
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
      home: EpicInitTransactionView(
          title: 'Please enter amount to send', password: password),
    );
  }
}

class EpicInitTransactionView extends StatefulWidget {
  const EpicInitTransactionView(
      {Key? key, required this.title, required this.password})
      : super(key: key);
  final String password;

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<EpicInitTransactionView> createState() => _EpicInitTransactionView();
}

class _EpicInitTransactionView extends State<EpicInitTransactionView> {
  var amount = "";
  var walletConfig = "";
  final storage = new FlutterSecureStorage();
  var initTxResponse = "";

  Future<void> _getWalletConfig() async {
    var config = await storage.read(key: "config");
    String strConf = json.encode(config);

    setState(() {
      walletConfig = strConf;
    });
  }

  String _initTransaction(
      Pointer<Utf8> config,
      Pointer<Utf8> password,
      Pointer<Int8> amount,
      Pointer<Int8> minimumConfirmations,
      Pointer<Int8> selectionStrategyUseAll) {
    final Pointer<Utf8> createTransactionPtr = createTransaction(config,
        password, amount, minimumConfirmations, selectionStrategyUseAll);

    final String createTransactionStr = createTransactionPtr.toDartString();
    return createTransactionStr;
  }

  void _setAmount(value) {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      amount = amount + value;
    });
  }

  void _setInitTxResponse(value) {
    setState(() {
      initTxResponse = value;
    });
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    _getWalletConfig();
    String password = widget.password;
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
                // The validator receives the text that the user has entered.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }

                  _setAmount(value);

                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () {
                  print("Amount is $amount");
                  String password = widget.password;
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    print("Amount is $amount");
                    print("Password is  $password");
                    const minimumConfirmations = "10";
                    const selectionStrategyUseAll = "0";

                    String decodeConfig = json.decode(walletConfig);
                    final Pointer<Utf8> configPointer =
                        decodeConfig.toNativeUtf8();
                    final Pointer<Utf8> passwordPtr = password.toNativeUtf8();
                    final amountPtr = amount.toNativeUtf8().cast<Int8>();
                    final minimumConfirmatiosPtr =
                        minimumConfirmations.toNativeUtf8().cast<Int8>();
                    final selectionStrategyUseAllPtr =
                        selectionStrategyUseAll.toNativeUtf8().cast<Int8>();

                    String transaction = _initTransaction(
                        configPointer,
                        passwordPtr,
                        amountPtr,
                        minimumConfirmatiosPtr,
                        selectionStrategyUseAllPtr);
                    _setInitTxResponse(transaction);
                  }
                },
                child: const Text('Init Transaction'),
              ),

              TextFormField(
                decoration: InputDecoration(hintText: initTxResponse),
                enabled: false,
                maxLines: 10,
                // The validator receives the text that the user has entered.
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
