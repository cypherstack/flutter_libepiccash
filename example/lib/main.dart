import 'package:flutter/material.dart';
import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_libepiccash/flutter_libepiccash.dart';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:flutter_libepiccash/epic_cash.dart';

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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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

  Future<String> createFolder(String folderName) async {
    io.Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    print(appDocPath);

    final io.Directory _appDocDir = await getApplicationDocumentsDirectory();
    final io.Directory _appDocDirFolder =
        io.Directory('${_appDocDir.path}/$folderName/');

    if (await _appDocDirFolder.exists()) {
      //if folder already exists return path
      return _appDocDirFolder.path;
    } else {
      //if folder not exists create folder and then return its path
      final io.Directory _appDocDirNewFolder =
          await _appDocDirFolder.create(recursive: true);
      return _appDocDirNewFolder.path;
    }
  }

  void _incrementCounter() {
    // final String nameStr = "John Smith";
    // final Pointer<Utf8> charPointer = nameStr.toNativeUtf8();
    // print("- Calling rust_greeting with argument:  $charPointer");
    //
    // final Pointer<Utf8> resultPtr = rustGreeting(charPointer);
    // print("- Result pointer:  $resultPtr");
    //
    // final String greetingStr = resultPtr.toDartString();
    // print("- Response string:  $greetingStr");

    final Pointer<Utf8> mnemonicPtr = walletMnemonic();
    print("- Result pointer:  $mnemonicPtr");

    final String mnemonicString = mnemonicPtr.toDartString();
    print("- Mnemonic string:  $mnemonicString");

    // final Pointer<Utf8> walletInitPtr = initWallet();
    //
    // final String walletInitString = walletInitPtr.toDartString();
    // print("- Mnemonic string:  $walletInitString");

    var config = {};
    config["wallet_dir"] =
        "/data/user/0/com.example.flutter_libepiccash_example/app_flutter/test/";
    config["check_node_api_http_addr"] = "http://95.216.215.107:3413";
    config["chain"] = "mainnet";
    config["account"] = "default";
    config["api_listen_port"] = 3413;
    config["api_listen_interface"] = "95.216.215.107";

    String strConf = json.encode(config);
    final Pointer<Utf8> configPointer = strConf.toNativeUtf8();

    // final String strMnemonic = mnemonicString;
    // final Pointer<Utf8> mnemonicPointer = strMnemonic.toNativeUtf8();
    const String strPassword = "58498542";
    final Pointer<Utf8> passwordPointer = strPassword.toNativeUtf8();

    const String strName = "EpicStack";
    final Pointer<Utf8> namePointer = strName.toNativeUtf8();

    print("- Calling wallet_init with arguments:");

    final Pointer<Utf8> initWalletPtr = initWallet(
        configPointer, mnemonicPointer, passwordPointer, namePointer);
    print("- Result pointer:  $initWalletPtr");

    final String initWalletStr = initWalletPtr.toDartString();
    print("- Response string:  $initWalletStr");

    final Pointer<Utf8> walletInfoPtr =
        walletInfo(configPointer, passwordPointer);
    final String walletInfoStr = walletInfoPtr.toDartString();
    print("Wallet balances info is : $walletInfoStr");

    const String recoveryPhrase =
        "leave rally pen marble wheat sell lumber asset wall blast later empty tape meat lady east expect badge cancel trust mosquito base trim marine";
    final Pointer<Utf8> recoveryPhrasePointer = recoveryPhrase.toNativeUtf8();
    final Pointer<Utf8> recoverWalletPtr =
        recoverWallet(configPointer, passwordPointer, recoveryPhrasePointer);
    final String recoverWalletStr = recoverWalletPtr.toDartString();
    print("Wallet recover is : $recoverWalletStr");
    print("Wallet info now is : $walletInfoStr");

    final Pointer<Utf8> walletPhrasePtr =
        walletPhrase(configPointer, passwordPointer);
    final String walletPhraseStr = walletPhrasePtr.toDartString();
    print("Recovery phrase is  : $walletPhraseStr");

    final Pointer<Utf8> scanOutputsPtr =
        scanOutPuts(configPointer, passwordPointer);
    final String scanOutputsStr = scanOutputsPtr.toDartString();

    print("Calling wallet scanner  : $scanOutputsStr");

    const amount = "1";
    final amountPtr = amount.toNativeUtf8().cast<Int8>();

    const minimumConfirmations = "10";
    final minimumConfirmatiosPtr =
        minimumConfirmations.toNativeUtf8().cast<Int8>();

    final Pointer<Utf8> createTransactionPtr = createTransaction(
        configPointer, passwordPointer, amountPtr, minimumConfirmatiosPtr);

    final String createTransactionStr = createTransactionPtr.toDartString();

    print("Create transactionresult  : $createTransactionStr");

    const refreshFromNode = true;
    final refreshFromNodePtr =
        refreshFromNode.toString().toNativeUtf8().cast<Bool>();

    final Pointer<Utf8> getTransactionsPtr = getTransactions(configPointer,
        passwordPointer, minimumConfirmatiosPtr, refreshFromNodePtr);
    final String getTransactionsStr = getTransactionsPtr.toDartString();
    print("Get wallet transactions : $getTransactionsStr");

    const txId = "4";
    final txIdPtr = txId.toNativeUtf8().cast<Int8>();

    final Pointer<Utf8> cancelTransactionPtr =
        cancelTransaction(configPointer, passwordPointer, txIdPtr);
    final String cancelTransactionStr = cancelTransactionPtr.toDartString();
    print("Cancel transaction by Id : $cancelTransactionStr");

    String slate =
        '{"version_info":{"version":3,"orig_version":3,"block_header_version":6},"num_participants":2,"id":"81c8d8d1-f1a6-40e6-8f5f-75da0b5b4744","tx":{"offset":"b813393ee10d08df03fb5facabf9cb1f5245da1da2cc2f7241075e1c09333ba4","body":{"inputs":[{"features":"Plain","commit":"088148dc0be1aebac25d372330a9aac0e7e2d175af5780054c10cbf660456468d1"}],"outputs":[{"features":"Plain","commit":"08249d2d9252b6cdd1d857169e350f60c8c5de7e00f54915e8e3d9437483ce4fc9","proof":"264b0abbcfa371597a979ec16f812541c9555f29888dc193d9b5135808d42540a4cd7260ec313c40f3c98ae12a70d450f2da519e8cba7e103bc498f9f8e6f40f05bbe5a21631ccd1189f3c0487cbcd1c5cb453524f0e27ead82bce32e878b067aca7cf93da8df2f183458ad8aea8be4191a770129c82d43aac05602fbc9934aa205fb63635d88b379b72506e261672d5e9971398634853e9657d2167c8062300cc36ebd39cc6e17ffc149174222d3392d110b18dea9b0a57a019fbe28d9a8bc82692813edc13c52d6412762789f3faf62cb7abe00c94c6d134409ee47daff122a82f79d2eb82adc940563bded79e3519e5895280bbaf7669044ce5bfc85d613db4f81c4bd18a3f49d6b7110414d8a99bf6e89a3f2e5ca89dd73a224f67fc090e9d5d7dd037158b7b48478a4a5ac5b54b9f55cfd52439cbeafc83224f81ab2eab55bc78e55f78607277d437418c345c91a4777cd5a35cfdced7e15c0e335a9f42889e00c39eb18d9338c0fcf3805ce3135e04d92b9493c3fcbb56e56996aac0c876d8f7748bd487d05b6dc8a643e7e0184e141318de2a4432c924fec993be65374970c8fd4627207d7babefe5c5987d19f33258cfaa3709799c41008156822afd27029d76fc7eaef2494de9d7762843212d7e2f3178884c0d65a5ef7716cf3aae0a8fe0f563686d63395ca7d008958868093a19f1f7cd2cf8e6b23d5886fb67629467c474214d0e27ce1956b72912e76e0224881b444c4708c917314e648ade2fa8e625014e738d657661958c04ab78e18da5ba16519a28a8cefa7cb1052c4a71811caafdf02902adabddc5c68919475e80489cf3a0601f6d6b5416b5427535dbcd5372ba596a610ed2731ebb321666a12eeaeaf6f66dfacea02f26907f2e279af73599638fd7be9bbd3e65f478ee2dcee823bfe379be69ab38ce2d28d9fd1bb757e4f6"}],"kernels":[{"features":"Plain","fee":"800000","lock_height":"0","excess":"000000000000000000000000000000000000000000000000000000000000000000","excess_sig":"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"}]}},"amount":"1","fee":"800000","height":"1480467","lock_height":"0","ttl_cutoff_height":null,"participant_data":[{"id":"0","public_blind_excess":"0398196ad586427950b610e2a87ad1a1c771a5360fbdffca05c84df23b53f3595f","public_nonce":"028f664294f5ecf659fe31064cfad697fa53e4672dd438946df6f2f55cebebc084","part_sig":null,"message":null,"message_sig":null}],"payment_proof":null}';

    final slatePtr = slate.toNativeUtf8().cast<Utf8>();
    final Pointer<Utf8> receiveTransactionPtr =
        receiveTransaction(configPointer, passwordPointer, slatePtr);
    final String receiveTransactionStr = receiveTransactionPtr.toDartString();

    print("Receive transaction response Id : $receiveTransactionStr");

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
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
