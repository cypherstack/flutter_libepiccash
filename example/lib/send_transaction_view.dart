import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/lib.dart';

class SendTransactionView extends StatefulWidget {
  final String walletName;
  final String password;
  final String wallet;
  final String epicboxConfig;

  const SendTransactionView({
    Key? key,
    required this.walletName,
    required this.password,
    required this.wallet,
    required this.epicboxConfig,
  }) : super(key: key);

  @override
  State<SendTransactionView> createState() => _SendTransactionViewState();
}

class _SendTransactionViewState extends State<SendTransactionView> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = "";
  String? _slateId;
  String? _commitId;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Creating transaction...";
      _slateId = null;
      _commitId = null;
    });

    try {
      final address = _addressController.text.trim();
      final amountStr = _amountController.text.trim();
      final note = _noteController.text.trim();

      // Parse amount as satoshis (EPIC has 8 decimal places).
      // User enters in EPIC, we convert to satoshis.
      final amountEpic = double.parse(amountStr);
      final amountSatoshis = (amountEpic * 100000000).toInt();

      setState(() {
        _statusMessage = "Checking if address is HTTP...";
      });

      // Check if it's an HTTP address or Epicbox address.
      final isHttpAddress =
          address.startsWith('http://') || address.startsWith('https://');

      if (isHttpAddress) {
        // Use HTTP send.
        setState(() {
          _statusMessage = "Sending via HTTP...";
        });

        final result = await LibEpiccash.txHttpSend(
          wallet: widget.wallet,
          selectionStrategyIsAll: 0,
          minimumConfirmations: 10,
          message: note,
          amount: amountSatoshis,
          address: address,
        );

        setState(() {
          _slateId = result.slateId;
          _commitId = result.commitId;
          _statusMessage =
              "Transaction sent successfully via HTTP!\n\nSlate ID: ${result.slateId}\nCommit ID: ${result.commitId}";
        });
      } else {
        // Use Epicbox send.
        setState(() {
          _statusMessage = "Sending via Epicbox...\nRecipient: $address";
        });

        print("DEBUG: Creating transaction");
        print("  Wallet: ${widget.wallet}");
        print("  Amount: $amountSatoshis satoshis ($amountEpic EPIC)");
        print("  Address: $address");
        print("  Epicbox config: ${widget.epicboxConfig}");

        final result = await LibEpiccash.createTransaction(
          wallet: widget.wallet,
          amount: amountSatoshis,
          address: address,
          secretKeyIndex: 0,
          epicboxConfig: widget.epicboxConfig,
          minimumConfirmations: 10,
          note: note,
        );

        print("DEBUG: Transaction created successfully");
        print("  Slate ID: ${result.slateId}");
        print("  Commit ID: ${result.commitId}");

        setState(() {
          _slateId = result.slateId;
          _commitId = result.commitId;
          _statusMessage =
              "Transaction created and sent to Epicbox!\n\nSlate ID: ${result.slateId}\nCommit ID: ${result.commitId}\n\nWaiting for recipient to finalize...\n\nMake sure recipient's listener is running!";
        });
      }
    } catch (e, stackTrace) {
      print("DEBUG: Transaction error: $e");
      print("Stack trace: $stackTrace");
      setState(() {
        _statusMessage = "Error sending transaction:\n\n$e\n\nCheck console for details.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Send EPIC',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Address',
                  hintText: 'epic1xxx@epicbox.epic.tech or https://...',
                  border: OutlineInputBorder(),
                  helperText:
                      'Enter Epicbox address (epic1xxx@...) or HTTP address',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a recipient address';
                  }
                  if (!value.contains('@') &&
                      !value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return 'Invalid address format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (EPIC)',
                  hintText: '0.00000000',
                  border: OutlineInputBorder(),
                  helperText: 'Enter amount in EPIC',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  hintText: 'Add a note to this transaction',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendTransaction,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isLoading ? 'Sending...' : 'Send Transaction'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              if (_statusMessage.isNotEmpty)
                Card(
                  color: _slateId != null ? Colors.green[50] : Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _slateId != null ? 'Success!' : 'Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _slateId != null ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
