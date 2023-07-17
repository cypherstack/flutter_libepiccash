import 'package:flutter/material.dart';
// import 'package:flutter_libepiccash_example/recover_view.dart';
import 'dart:async';

// import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_libepiccash/flutter_libepiccash.dart';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
// import 'package:flutter_libepiccash_example/wallet_name.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  print("CALLING FUNCTION >>>>> MAIN");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    String mnemonic = walletMnemonic();
    print("MNEMONIC IS $mnemonic");
    return MaterialApp(
      title: 'Flutter Demo',
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
      home: const MyHomePage(title: 'Epic Mobile Wallet'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  final greeting = "";

  // Future<String> createFolder(String folderName) async {
  //   Directory appDocDir = (await getApplicationDocumentsDirectory());
  //   if (Platform.isIOS) {
  //     appDocDir = (await getLibraryDirectory());
  //   }
  //   String appDocPath = appDocDir.path;
  //   print(appDocPath);
  //
  //   Directory _appDocDir = (await getApplicationDocumentsDirectory());
  //   if (Platform.isIOS) {
  //     _appDocDir = (await getLibraryDirectory());
  //   }
  //   final io.Directory _appDocDirFolder =
  //       io.Directory('${_appDocDir.path}/$folderName/');
  //
  //   if (await _appDocDirFolder.exists()) {
  //     //if folder already exists return path
  //     return _appDocDirFolder.path;
  //   } else {
  //     //if folder not exists create folder and then return its path
  //     final io.Directory _appDocDirNewFolder =
  //         await _appDocDirFolder.create(recursive: true);
  //     return _appDocDirNewFolder.path;
  //   }
  // }

  void _incrementCounter() {
    // final String nameStr = "John Smith";
    // final Pointer<Utf8> charPointer = nameStr.toNativeUtf8();
    // print("- Calling rust_greeting with argument:  $charPointer");

    // var config = {};
    // config["wallet_dir"] =
    //     "/data/user/0/com.example.flutter_libepiccash_example/app_flutter/test/";
    // config["check_node_api_http_addr"] = "http://95.216.215.107:3413";
    // config["chain"] = "mainnet";
    // config["account"] = "default";
    // config["api_listen_port"] = 3413;
    // config["api_listen_interface"] = "95.216.215.107";
    //
    // String strConf = json.encode(config);
    //
    // String addressInfo = getAddressInfo();
    // print("Address Info is");
    // print(addressInfo);
    // final Pointer<Utf8> configPointer = strConf.toNativeUtf8();

    // final height = getChainHeight(strConf);
    // print("Chain height is ");
    // print(height);

    // final Pointer<Utf8> walletInfoPtr =
    //     walletInfo(configPointer, passwordPointer);
    // final String walletInfoStr = walletInfoPtr.toDartString();
    // print("Wallet balances info is : $walletInfoStr");

    // final Pointer<Utf8> recoveryPhrasePointer = recoveryPhrase.toNativeUtf8();
    // final Pointer<Utf8> recoverWalletPtr =
    //     recoverWallet(configPointer, passwordPointer, recoveryPhrasePointer);
    // final String recoverWalletStr = recoverWalletPtr.toDartString();
    // print("Wallet recover is : $recoverWalletStr");
    // print("Wallet info now is : $walletInfoStr");

    // final Pointer<Utf8> walletPhrasePtr =
    //     walletPhrase(configPointer, passwordPointer);
    // final String walletPhraseStr = walletPhrasePtr.toDartString();
    // print("Recovery phrase is  : $walletPhraseStr");
    //
    // final Pointer<Utf8> scanOutputsPtr =
    //     scanOutPuts(configPointer, passwordPointer);
    // final String scanOutputsStr = scanOutputsPtr.toDartString();
    //
    // print("Calling wallet scanner  : $scanOutputsStr");

    // const amount = "1";
    // final amountPtr = amount.toNativeUtf8().cast<Int8>();
    //
    // const minimumConfirmations = "10";
    // final minimumConfirmatiosPtr =
    //     minimumConfirmations.toNativeUtf8().cast<Int8>();
    //
    // final Pointer<Utf8> createTransactionPtr = createTransaction(
    //     configPointer, passwordPointer, amountPtr, minimumConfirmatiosPtr);
    //
    // final String createTransactionStr = createTransactionPtr.toDartString();
    //
    // print("Create transactionresult  : $createTransactionStr");

    // const refreshFromNode = true;
    // final refreshFromNodePtr =
    //     refreshFromNode.toString().toNativeUtf8().cast<Bool>();

    // final Pointer<Utf8> getTransactionsPtr = getTransactions(configPointer,
    //     passwordPointer, minimumConfirmatiosPtr, refreshFromNodePtr);
    // final String getTransactionsStr = getTransactionsPtr.toDartString();
    // print("Get wallet transactions : $getTransactionsStr");

    // const txId = "6";
    // final txIdPtr = txId.toNativeUtf8().cast<Int8>();
    //
    // final Pointer<Utf8> cancelTransactionPtr =
    //     cancelTransaction(configPointer, passwordPointer, txIdPtr);
    // final String cancelTransactionStr = cancelTransactionPtr.toDartString();
    // print("Cancel transaction by Id : $cancelTransactionStr");

    //
    // final slatePtr = slate.toNativeUtf8().cast<Utf8>();
    // final Pointer<Utf8> receiveTransactionPtr =
    //     receiveTransaction(configPointer, passwordPointer, slatePtr);
    // final String receiveTransactionStr = receiveTransactionPtr.toDartString();
    //
    // print("Receive transaction response Id : $receiveTransactionStr");

    // createFolder("test").then((value) {
    //   print(value);
    // });

    setState(() {
      // greeting = $gre
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
