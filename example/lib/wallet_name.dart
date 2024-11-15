import 'package:flutter/material.dart';
import 'package:flutter_libepiccash_example/recover_view.dart';

class WalletNameView extends StatelessWidget {
  const WalletNameView({Key? key, required this.recover}) : super(key: key);
  final bool recover;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Name'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecoverWalletView(name: 'example'),
              ),
            );
          },
          child: const Text('Recover Wallet'),
        ),
      ),
    );
  }
}
