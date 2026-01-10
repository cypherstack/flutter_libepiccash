import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/lib.dart';
import 'package:flutter_libepiccash_example/wallet_info_view.dart';
import 'package:flutter_libepiccash_example/wallet_state_manager.dart';

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
  final TextEditingController _startHeightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';
  int _chainHeight = 0;

  @override
  void initState() {
    super.initState();
    _fetchChainHeight();
  }

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
              const Text(
                'Scan start height (optional)',
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'Enter the approximate block height from when your wallet was created to speed up scanning.',
                style: TextStyle(fontSize: 12.0, color: Colors.grey),
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _startHeightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '0 (scan from genesis)',
                  border: const OutlineInputBorder(),
                  helperText: _chainHeight > 0
                      ? 'Current chain height: $_chainHeight'
                      : null,
                ),
              ),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  _suggestedHeightButton('Jan 2026', 3150000),
                  _suggestedHeightButton('Dec 2025', 3100000),
                  _suggestedHeightButton('Jan 2025', 2750000),
                  _suggestedHeightButton('Jan 2024', 2225000),
                  _suggestedHeightButton('Jan 2023', 1700000),
                ],
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

  Future<void> _fetchChainHeight() async {
    try {
      String config = await EpicboxConfig.getDefaultConfig(widget.name);
      final height = await LibEpiccash.getChainHeight(config: config);
      setState(() {
        _chainHeight = height;
      });
    } catch (e) {
      // Ignore errors - chain height display is optional.
    }
  }

  Widget _suggestedHeightButton(String label, int height) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _startHeightController.text = height.toString();
        });
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12.0)),
    );
  }

  Future<void> _recoverWallet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final startHeight = int.tryParse(_startHeightController.text) ?? 0;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String config = await EpicboxConfig.getDefaultConfig(widget.name);

      // Save the start height before recovery so wallet_info_view uses it.
      await WalletStateManager.saveDefaultStartHeight(widget.name, startHeight);
      await WalletStateManager.saveLastScannedBlock(widget.name, startHeight);

      try {
        await LibEpiccash.recoverWallet(
          config: config,
          mnemonic: _mnemonicController.text.trim(),
          password: _passwordController.text,
          name: widget.name,
        );
      } catch (e) {
        // Clear saved state on failure.
        await WalletStateManager.clearWalletState(widget.name);
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
