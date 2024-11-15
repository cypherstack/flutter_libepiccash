import 'package:flutter/material.dart';
import 'package:flutter_libepiccash_example/mnemonic_view.dart';
import 'package:flutter_libepiccash_example/util.dart';

class WalletNameView extends StatelessWidget {
  const WalletNameView({Key? key, required this.recover}) : super(key: key);
  final bool recover;

  @override
  Widget build(BuildContext context) {
    final TextEditingController _controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(recover ? 'Recover Wallet' : 'Create Wallet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Wallet Name'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_controller.text.isNotEmpty) {
                  // Guarantee wallet directory structure.
                  final walletPath = await createFolder(_controller.text);
                  if (walletPath == "directory_exists" ||
                      walletPath != "error") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MnemonicView(
                          name: _controller.text,
                          password: '', // Handled in MnemonicView
                        ),
                      ),
                    );
                  } else {
                    print("Error: Wallet directory could not be created.");
                  }
                }
              },
              child: Text(recover ? 'Recover' : 'Create'),
            )
          ],
        ),
      ),
    );
  }
}
