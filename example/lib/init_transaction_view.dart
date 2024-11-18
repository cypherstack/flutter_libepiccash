import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'epicbox_config.dart';

class InitTransactionView extends StatelessWidget {
  const InitTransactionView({Key? key, required this.password})
      : super(key: key);
  final String password;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initiate Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: EpicInitTransactionView(
          title: 'Please enter amount to send', password: password),
    );
  }
}

class EpicInitTransactionView extends StatefulWidget {
  const EpicInitTransactionView(
      {Key? key, required this.title, required this.password})
      : super(key: key);
  final String password;

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
    walletConfig = await EpicboxConfig.getDefaultConfig('walletName');
  }

  String _initTransaction(String config, String password, int amount,
      String minimumConfirmations, String selectionStrategyUseAll) {
    try {
      return createTransaction(
        config,
        amount,
        '',
        0, // Assuming default secretKeyIndex = 0
        '{}', // Assuming no specific epicboxConfig
        int.parse(minimumConfirmations),
        '', // Assuming no note
      ).toString();
    } catch (e) {
      return "Error initiating transaction: $e";
    }
  }

  void _setAmount(value) {
    setState(() {
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
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    String walletConfig =
                        await EpicboxConfig.getDefaultConfig('walletName');

                    const minimumConfirmations = "10";
                    const selectionStrategyUseAll = "0";

                    String transaction = _initTransaction(
                      walletConfig,
                      widget.password,
                      int.parse(amount),
                      minimumConfirmations,
                      selectionStrategyUseAll,
                    );
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
  }
}
