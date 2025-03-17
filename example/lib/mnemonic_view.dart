import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/lib.dart';
import 'package:flutter_libepiccash_example/wallet_info_view.dart';
import 'package:path_provider/path_provider.dart';

import 'epicbox_config.dart';

class MnemonicView extends StatefulWidget {
  final String name;

  const MnemonicView({Key? key, required this.name}) : super(key: key);

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

  Future<void> _cleanupWalletDirectory() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      final walletDir = Directory(
          '${appDir.path}/flutter_libepiccash/example/wallets/${widget.name}');
      if (await walletDir.exists()) {
        await walletDir.delete(recursive: true);
      }
    } catch (e) {
      print("Error cleaning up wallet directory: $e");
    }
  }

  void _handleBack() async {
    await _cleanupWalletDirectory();
    if (mounted) {
      // Pop back to the wallet management view.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _fetchMnemonic() {
    try {
      final mnemonicValue = LibEpiccash.getMnemonic();
      setState(() {
        mnemonic = mnemonicValue;
      });
    } catch (e) {
      print('Error fetching mnemonic: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching mnemonic: $e')),
        );
      }
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
            onPressed: _handleBack,
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
          onPressed: _handleBack,
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
                const Text(
                  'Write down these words and keep them safe. They are needed to recover your wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20.0),
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

    setState(() {
      _isLoading = true;
    });

    try {
      String config = await EpicboxConfig.getDefaultConfig(widget.name);

      // Initialize the wallet
      await LibEpiccash.initializeNewWallet(
        config: config,
        mnemonic: mnemonic,
        password: _passwordController.text,
        name: widget.name,
      );

      // Add a small delay to ensure wallet creation is complete
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Pop all routes and push the new wallet view
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => WalletInfoView(
              walletName: widget.name,
              password: _passwordController.text,
            ),
          ),
          (route) =>
              route.isFirst, // Keep only the first route (wallet management)
        );
      }
    } catch (e) {
      print('Error creating wallet: $e');
      await _cleanupWalletDirectory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating wallet: $e')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
