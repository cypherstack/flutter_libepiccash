import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/lib.dart';
import 'package:flutter_libepiccash_example/wallet_info_view.dart';

import 'epicbox_config.dart';

class MnemonicView extends StatefulWidget {
  final String name;

  MnemonicView({Key? key, required this.name}) : super(key: key);

  @override
  _MnemonicViewState createState() => _MnemonicViewState();
}

class _MnemonicViewState extends State<MnemonicView> {
  String mnemonic = '';
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMnemonic();
  }

  void _fetchMnemonic() {
    try {
      final mnemonicValue = LibEpiccash.getMnemonic();
      setState(() {
        mnemonic = mnemonicValue;
      });
    } catch (e) {
      print('Error fetching mnemonic: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching mnemonic: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (mnemonic.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Wallet Mnemonic'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Mnemonic'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  mnemonic,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16.0),
                ),
                const SizedBox(height: 20.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _createWallet,
                        child: const Text('Create Wallet'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createWallet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    String enteredPassword = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      String config = await EpicboxConfig.getDefaultConfig(widget.name);
      await LibEpiccash.initializeNewWallet(
        config: config,
        mnemonic: mnemonic,
        password: enteredPassword,
        name: widget.name,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WalletInfoView(
            walletName: widget.name,
            password: enteredPassword,
          ),
        ),
      );
    } catch (e) {
      print('Error creating wallet: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating wallet: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
