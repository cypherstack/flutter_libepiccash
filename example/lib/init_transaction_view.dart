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
  var address = "";
  var walletConfig = "";
  final storage = new FlutterSecureStorage();
  var initTxResponse = "";

  Future<void> _getWalletConfig() async {
    walletConfig = await EpicboxConfig.getDefaultConfig('walletName');
  }

  Future<String> _initTransaction(String config, String password, int amount,
      String address, String minimumConfirmations) async {
    try {
      // Open wallet to get wallet pointer (similar to Stack Wallet).
      final wallet = openWallet(config, password);
      if (wallet.contains('Error')) {
        return 'Error opening wallet: $wallet';
      }

      // Get epicbox config.
      final epicboxConfig = await EpicboxConfig.getDefaultConfig('walletName');

      // Create transaction with wallet pointer (not config).
      final result = await createTransaction(
        wallet, // wallet pointer, not config.
        amount,
        address,
        0, // secretKeyIndex
        epicboxConfig,
        int.parse(minimumConfirmations),
        'Example transaction', // note.
      );
      return result;
    } catch (e) {
      return "Error initiating transaction: $e";
    }
  }

  void _setAmount(value) {
    setState(() {
      amount = value;
    });
  }

  void _setAddress(value) {
    setState(() {
      address = value;
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
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Amount (in smallest unit)',
                    hintText: 'Enter amount',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter valid number';
                    }
                    _setAmount(value);
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Recipient Address',
                    hintText: 'Enter Epic address',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter address';
                    }
                    _setAddress(value);
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      String walletConfig =
                          await EpicboxConfig.getDefaultConfig('walletName');

                      const minimumConfirmations = "10";

                      String transaction = await _initTransaction(
                        walletConfig,
                        widget.password,
                        int.parse(amount),
                        address,
                        minimumConfirmations,
                      );
                      _setInitTxResponse(transaction);
                    }
                  },
                  child: const Text('Create Transaction'),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: TextFormField(
                      decoration: InputDecoration(
                        hintText: initTxResponse.isEmpty
                            ? 'Transaction result will appear here'
                            : initTxResponse,
                        border: const OutlineInputBorder(),
                      ),
                      enabled: false,
                      maxLines: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
