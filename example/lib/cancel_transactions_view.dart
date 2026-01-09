import 'package:flutter/material.dart';
import 'package:flutter_libepiccash/lib.dart';
import 'package:flutter_libepiccash/models/transaction.dart';

class CancelTransactionsView extends StatefulWidget {
  final String walletName;
  final String password;

  const CancelTransactionsView({
    Key? key,
    required this.walletName,
    required this.password,
  }) : super(key: key);

  @override
  State<CancelTransactionsView> createState() => _CancelTransactionsViewState();
}

class _CancelTransactionsViewState extends State<CancelTransactionsView> {
  List<Transaction>? _transactions;
  bool _isLoading = true;
  String? _error;
  String? _wallet;
  Set<String> _cancelling = {};

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final config = await _getConfig();
      final wallet = await LibEpiccash.openWallet(
        config: config,
        password: widget.password,
      );
      final transactions = await LibEpiccash.getTransactions(
        wallet: wallet,
        refreshFromNode: 1,
      );

      // Filter to only show cancellable transactions.
      final cancellable = transactions.where((tx) {
        return (tx.txType == TransactionType.TxSent ||
                tx.txType == TransactionType.TxReceived) &&
            !tx.confirmed;
      }).toList();

      setState(() {
        _wallet = wallet;
        _transactions = cancellable;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<String> _getConfig() async {
    // Simple config for cancellation.
    final walletDir = '/home/user/Documents/flutter_libepiccash/${widget.walletName}';
    return '''
{
  "wallet_dir": "$walletDir",
  "check_node_api_http_addr": "http://epiccash.stackwallet.com:3413",
  "chain": "mainnet",
  "account": "default",
  "api_listen_port": 3413,
  "api_listen_interface": "epiccash.stackwallet.com"
}
''';
  }

  Future<void> _cancelTransaction(String? txSlateId, int txId) async {
    if (txSlateId == null || _wallet == null) return;

    setState(() {
      _cancelling.add(txSlateId);
    });

    try {
      print("DEBUG: Cancelling transaction");
      print("  Slate ID: $txSlateId");
      print("  TX ID: $txId");

      await LibEpiccash.cancelTransaction(
        wallet: _wallet!,
        transactionId: txId.toString(),
      );

      print("DEBUG: Transaction cancelled successfully");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction $txSlateId cancelled'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload transactions.
      await _loadTransactions();
    } catch (e, stackTrace) {
      print("DEBUG: Cancel error: $e");
      print("Stack trace: $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _cancelling.remove(txSlateId);
      });
    }
  }

  String _formatAmount(String amountString) {
    try {
      final amountSatoshis = int.parse(amountString);
      final amountEpic = amountSatoshis / 100000000;
      return amountEpic.toStringAsFixed(8);
    } catch (e) {
      return '0.00000000';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancel Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadTransactions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTransactions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _transactions == null || _transactions!.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'No pending transactions to cancel',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All transactions are confirmed or already cancelled',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            color: Colors.orange[50],
                            child: const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning,
                                          color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text(
                                        'Cancel Pending Transactions',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'These transactions are stuck awaiting finalization. '
                                    'Cancelling will unlock the funds and remove the transaction.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _transactions!.length,
                            itemBuilder: (context, index) {
                              final tx = _transactions![index];
                              final isCancelling =
                                  _cancelling.contains(tx.txSlateId);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        tx.txType == TransactionType.TxSent
                                            ? Colors.red[100]
                                            : Colors.blue[100],
                                    child: Icon(
                                      tx.txType == TransactionType.TxSent
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color:
                                          tx.txType == TransactionType.TxSent
                                              ? Colors.red
                                              : Colors.blue,
                                    ),
                                  ),
                                  title: Text(
                                    tx.txType == TransactionType.TxSent
                                        ? 'Sent (Pending)'
                                        : 'Received (Pending)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Amount: ${_formatAmount(tx.amountCredited)} EPIC',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (tx.txSlateId != null)
                                        Text(
                                          'Slate ID: ${tx.txSlateId!.substring(0, 16)}...',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                    ],
                                  ),
                                  trailing: isCancelling
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () => _cancelTransaction(
                                            tx.txSlateId,
                                            tx.id,
                                          ),
                                          icon:
                                              const Icon(Icons.cancel, size: 16),
                                          label: const Text('Cancel'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
