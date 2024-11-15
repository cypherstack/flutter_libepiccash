import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash_example/init_transaction_view.dart';
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
  final storage = const FlutterSecureStorage();
  bool isLoading = true;
  Map<String, dynamic> walletData = {};
  List<dynamic> transactionsList = [];

  Future<void> _getWalletConfig() async {
    try {
      var config = await storage.read(key: "config");
      if (config == null || config.isEmpty) {
        throw Exception("Wallet configuration not found.");
      }

      setState(() {
        walletConfig = config;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading wallet configuration: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getWalletConfig();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    try {
      // Decode walletConfig safely
      Map<String, dynamic> config = json.decode(walletConfig);

      // Dummy wallet info for demonstration
      String walletInfo = json.encode({
        "total": 1000,
        "amount_awaiting_finalization": 100,
        "amount_awaiting_confirmation": 50,
        "amount_currently_spendable": 850,
        "amount_locked": 0
      });
      walletData = json.decode(walletInfo);

      // Dummy transactions list for demonstration
      String transactions = json.encode([
        {"id": 1, "amount": 100, "status": "confirmed"},
        {"id": 2, "amount": 50, "status": "pending"}
      ]);
      transactionsList = json.decode(transactions);
    } catch (e) {
      print("Error parsing wallet data: $e");
      return Center(child: Text("Failed to load wallet data."));
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          children: <Widget>[
            Text("Total Amount : ${walletData['total']}"),
            Text(
                "Awaiting Finalization : ${walletData['amount_awaiting_finalization']}"),
            Text(
                "Awaiting Confirmation : ${walletData['amount_awaiting_confirmation']}"),
            Text("Spendable : ${walletData['amount_currently_spendable']}"),
            Text("Locked : ${walletData['amount_locked']}"),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InitTransactionView(
                      password: widget.password,
                    ),
                  ),
                );
              },
              child: const Text("Init Transaction"),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: transactionsList.length,
                itemBuilder: (context, index) {
                  var transaction = transactionsList[index];
                  return ListTile(
                    title: Text("Transaction ID: ${transaction['id']}"),
                    subtitle: Text(
                        "Amount: ${transaction['amount']} - Status: ${transaction['status']}"),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
