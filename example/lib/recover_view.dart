import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/lib.dart';
import 'package:flutter_libepiccash_example/wallet_info_view.dart';

import 'epicbox_config.dart';

class RecoverWalletView extends StatefulWidget {
  final String name;

  RecoverWalletView({Key? key, required this.name}) : super(key: key);

  @override
  _RecoverWalletViewState createState() => _RecoverWalletViewState();
}

class _RecoverWalletViewState extends State<RecoverWalletView> {
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Wallet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your recovery phrase',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _mnemonicController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter your 24-word recovery phrase',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your recovery phrase';
                  }
                  final wordCount = value.trim().split(' ').length;
                  if (wordCount != 24) {
                    return 'Recovery phrase must contain exactly 24 words';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Enter new wallet password (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24.0),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _recoverWallet,
                      child: const Text('Recover Wallet'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recoverWallet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String config = await EpicboxConfig.getDefaultConfig(widget.name);

      try {
        await LibEpiccash.recoverWallet(
          config: config,
          mnemonic: _mnemonicController.text.trim(),
          password: _passwordController.text,
          name: widget.name,
        );
      } catch (e) {
        setState(() {
          _errorMessage = 'Error recovering wallet: $e';
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WalletInfoView(
            walletName: widget.name,
            password: _passwordController.text,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error recovering wallet: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
