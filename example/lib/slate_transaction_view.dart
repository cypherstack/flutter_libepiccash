import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libepiccash/lib.dart';

/// View for manual slate (slatepack) transactions.
///
/// This demonstrates the 3-step transaction process:
/// 1. Sender: Create slate (returns slate JSON to share)
/// 2. Receiver: Receive slate (processes incoming slate, returns response)
/// 3. Sender: Finalize slate (finalizes and broadcasts to network)
class SlateTransactionView extends StatefulWidget {
  final String walletName;
  final String password;
  final String wallet;
  final String epicboxConfig;

  const SlateTransactionView({
    Key? key,
    required this.walletName,
    required this.password,
    required this.wallet,
    required this.epicboxConfig,
  }) : super(key: key);

  @override
  State<SlateTransactionView> createState() => _SlateTransactionViewState();
}

class _SlateTransactionViewState extends State<SlateTransactionView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slate Transactions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create', icon: Icon(Icons.add_circle_outline)),
            Tab(text: 'Receive', icon: Icon(Icons.download)),
            Tab(text: 'Finalize', icon: Icon(Icons.check_circle_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CreateSlateTab(
            wallet: widget.wallet,
            epicboxConfig: widget.epicboxConfig,
          ),
          _ReceiveSlateTab(
            wallet: widget.wallet,
          ),
          _FinalizeSlateTab(
            wallet: widget.wallet,
          ),
        ],
      ),
    );
  }
}

/// Tab for creating a new slate (Step 1 - Sender).
class _CreateSlateTab extends StatefulWidget {
  final String wallet;
  final String epicboxConfig;

  const _CreateSlateTab({
    required this.wallet,
    required this.epicboxConfig,
  });

  @override
  State<_CreateSlateTab> createState() => _CreateSlateTabState();
}

class _CreateSlateTabState extends State<_CreateSlateTab> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  String? _slateJson;
  String? _slateId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _createSlate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating slate...';
      _slateJson = null;
      _slateId = null;
    });

    try {
      final amountStr = _amountController.text.trim();
      final note = _noteController.text.trim();

      // Parse amount as satoshis.
      final amountEpic = double.parse(amountStr);
      final amountSatoshis = (amountEpic * 100000000).toInt();

      final result = await LibEpiccash.createTransaction(
        wallet: widget.wallet,
        amount: amountSatoshis,
        // Address is not used in slate mode, but we need to pass something.
        address: 'slate',
        secretKeyIndex: 0,
        epicboxConfig: widget.epicboxConfig,
        minimumConfirmations: 10,
        note: note,
        returnSlate: true, // This is the key flag for slate mode.
      );

      setState(() {
        _slateId = result.slateId;
        _slateJson = result.slateJson;
        _statusMessage = 'Slate created successfully!\n\n'
            'Slate ID: ${result.slateId}\n\n'
            'Copy the slate JSON below and send it to the receiver.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error creating slate:\n\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copySlateToClipboard() {
    if (_slateJson != null) {
      Clipboard.setData(ClipboardData(text: _slateJson!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slate copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Step 1: Create Slate',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a transaction slate to send to the receiver manually.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (EPIC)',
                hintText: '0.00000000',
                border: OutlineInputBorder(),
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
              onPressed: _isLoading ? null : _createSlate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle),
              label: Text(_isLoading ? 'Creating...' : 'Create Slate'),
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
                      Text(_statusMessage),
                    ],
                  ),
                ),
              ),
            if (_slateJson != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Slate JSON:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _copySlateToClipboard,
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy to clipboard',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _slateJson!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tab for receiving a slate (Step 2 - Receiver).
class _ReceiveSlateTab extends StatefulWidget {
  final String wallet;

  const _ReceiveSlateTab({
    required this.wallet,
  });

  @override
  State<_ReceiveSlateTab> createState() => _ReceiveSlateTabState();
}

class _ReceiveSlateTabState extends State<_ReceiveSlateTab> {
  final _slateInputController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  String? _responseSlateJson;
  String? _slateId;

  @override
  void dispose() {
    _slateInputController.dispose();
    super.dispose();
  }

  Future<void> _receiveSlate() async {
    final slateJson = _slateInputController.text.trim();
    if (slateJson.isEmpty) {
      setState(() {
        _statusMessage = 'Please paste the sender\'s slate JSON';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Processing slate...';
      _responseSlateJson = null;
      _slateId = null;
    });

    try {
      final result = await LibEpiccash.txReceive(
        wallet: widget.wallet,
        slateJson: slateJson,
      );

      setState(() {
        _slateId = result.slateId;
        _responseSlateJson = result.slateJson;
        _statusMessage = 'Slate processed successfully!\n\n'
            'Slate ID: ${result.slateId}\n\n'
            'Copy the response slate JSON below and send it back to the sender.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error receiving slate:\n\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyResponseToClipboard() {
    if (_responseSlateJson != null) {
      Clipboard.setData(ClipboardData(text: _responseSlateJson!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Response slate copied to clipboard')),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _slateInputController.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Step 2: Receive Slate',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste the sender\'s slate JSON here to add your signature.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Incoming Slate JSON:'),
              const Spacer(),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste, size: 18),
                label: const Text('Paste'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _slateInputController,
            decoration: const InputDecoration(
              hintText: 'Paste the sender\'s slate JSON here...',
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _receiveSlate,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_isLoading ? 'Processing...' : 'Receive Slate'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.green,
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
                    Text(_statusMessage),
                  ],
                ),
              ),
            ),
          if (_responseSlateJson != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Response Slate JSON:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _copyResponseToClipboard,
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText(
                  _responseSlateJson!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tab for finalizing a slate (Step 3 - Sender).
class _FinalizeSlateTab extends StatefulWidget {
  final String wallet;

  const _FinalizeSlateTab({
    required this.wallet,
  });

  @override
  State<_FinalizeSlateTab> createState() => _FinalizeSlateTabState();
}

class _FinalizeSlateTabState extends State<_FinalizeSlateTab> {
  final _slateInputController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  String? _slateId;
  String? _commitId;

  @override
  void dispose() {
    _slateInputController.dispose();
    super.dispose();
  }

  Future<void> _finalizeSlate() async {
    final slateJson = _slateInputController.text.trim();
    if (slateJson.isEmpty) {
      setState(() {
        _statusMessage = 'Please paste the receiver\'s response slate JSON';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Finalizing and broadcasting transaction...';
      _slateId = null;
      _commitId = null;
    });

    try {
      final result = await LibEpiccash.txFinalize(
        wallet: widget.wallet,
        slateJson: slateJson,
      );

      setState(() {
        _slateId = result.slateId;
        _commitId = result.commitId;
        _statusMessage = 'Transaction finalized and broadcast!\n\n'
            'Slate ID: ${result.slateId}\n'
            'Commit ID: ${result.commitId}\n\n'
            'The transaction has been submitted to the network.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error finalizing slate:\n\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _slateInputController.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Step 3: Finalize Slate',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste the receiver\'s response slate to finalize and broadcast.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Response Slate JSON:'),
              const Spacer(),
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste, size: 18),
                label: const Text('Paste'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _slateInputController,
            decoration: const InputDecoration(
              hintText: 'Paste the receiver\'s response slate JSON here...',
              border: OutlineInputBorder(),
            ),
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _finalizeSlate,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle),
            label:
                Text(_isLoading ? 'Finalizing...' : 'Finalize & Broadcast'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.orange,
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
                      _slateId != null ? 'Transaction Complete!' : 'Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _slateId != null ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
