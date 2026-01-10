import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libepiccash/lib.dart';
import 'package:flutter_libepiccash/models/transaction.dart';

import 'epicbox_config.dart';

class TransactionView extends StatefulWidget {
  final String walletName;
  final String password;

  const TransactionView(
      {Key? key, required this.walletName, required this.password})
      : super(key: key);

  @override
  State<TransactionView> createState() => _TransactionViewState();
}

class _TransactionViewState extends State<TransactionView> {
  List<Transaction>? _transactions;
  bool _isLoading = true;
  String? _error;
  String? _wallet;
  Set<int> _cancelling = {};

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
      final config = await EpicboxConfig.getDefaultConfig(widget.walletName);
      final wallet =
          await LibEpiccash.openWallet(config: config, password: widget.password);
      final transactions = await LibEpiccash.getTransactions(
        wallet: wallet,
        refreshFromNode: 1,
      );

      setState(() {
        _wallet = wallet;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelTransaction(Transaction tx) async {
    if (_wallet == null || tx.txSlateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot cancel: Transaction has no slate ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _cancelling.add(tx.id);
    });

    try {
      print("DEBUG: Cancelling transaction");
      print("  TX ID: ${tx.id}");
      print("  Slate ID: ${tx.txSlateId}");

      await LibEpiccash.cancelTransaction(
        wallet: _wallet!,
        transactionId: tx.txSlateId!,
      );

      print("DEBUG: Transaction cancelled successfully");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction ${tx.txSlateId ?? tx.id.toString()} cancelled'),
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

      setState(() {
        _cancelling.remove(tx.id);
      });
    }
  }

  bool _canCancelTransaction(Transaction tx) {
    final canCancel = (tx.txType == TransactionType.TxSent ||
            tx.txType == TransactionType.TxReceived ||
            tx.txType == TransactionType.Unknown) &&
        !tx.confirmed;

    print("DEBUG: Transaction ${tx.id} (${tx.txSlateId})");
    print("  Type: ${tx.txType}");
    print("  Confirmed: ${tx.confirmed}");
    print("  Can cancel: $canCancel");

    return canCancel;
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

  Color _getStatusColor(Transaction tx) {
    switch (tx.txType) {
      case TransactionType.TxReceived:
      case TransactionType.ConfirmedCoinbase:
        return Colors.green;
      case TransactionType.TxSent:
        return Colors.red;
      case TransactionType.TxReceivedCancelled:
      case TransactionType.TxSentCancelled:
        return Colors.orange;
      case TransactionType.UnconfirmedCoinbase:
        return Colors.blue;
      case TransactionType.Unknown:
        // Show orange for pending outgoing, grey otherwise.
        return _isOutgoingUnknown(tx) ? Colors.orange : Colors.grey;
    }
  }

  String _formatTxType(Transaction tx) {
    switch (tx.txType) {
      case TransactionType.TxReceived:
        return 'Received';
      case TransactionType.TxSent:
        return 'Sent';
      case TransactionType.TxReceivedCancelled:
        return 'Received (Cancelled)';
      case TransactionType.TxSentCancelled:
        return 'Sent (Cancelled)';
      case TransactionType.ConfirmedCoinbase:
        return 'Coinbase (Confirmed)';
      case TransactionType.UnconfirmedCoinbase:
        return 'Coinbase (Unconfirmed)';
      case TransactionType.Unknown:
        return _isOutgoingUnknown(tx) ? 'Pending Send' : 'Unknown';
    }
  }

  IconData _getTxIcon(Transaction tx) {
    switch (tx.txType) {
      case TransactionType.TxReceived:
      case TransactionType.ConfirmedCoinbase:
      case TransactionType.UnconfirmedCoinbase:
        return Icons.arrow_downward;
      case TransactionType.TxSent:
        return Icons.arrow_upward;
      case TransactionType.TxReceivedCancelled:
      case TransactionType.TxSentCancelled:
        return Icons.cancel;
      case TransactionType.Unknown:
        // Show send icon for pending outgoing, sync otherwise.
        return _isOutgoingUnknown(tx) ? Icons.arrow_upward : Icons.sync;
    }
  }

  String _getDisplayAmount(Transaction tx) {
    print("DEBUG _getDisplayAmount: txType=${tx.txType}, debited=${tx.amountDebited}, credited=${tx.amountCredited}");
    final debited = int.tryParse(tx.amountDebited) ?? 0;
    final credited = int.tryParse(tx.amountCredited) ?? 0;

    switch (tx.txType) {
      case TransactionType.TxSent:
      case TransactionType.TxSentCancelled:
        // For sent transactions, show net amount (debited - credited = amount sent + fee).
        final netAmount = debited - credited;
        print("DEBUG: TxSent/Cancelled - debited=$debited, credited=$credited, net=$netAmount");
        return netAmount.toString();
      case TransactionType.TxReceived:
      case TransactionType.TxReceivedCancelled:
      case TransactionType.ConfirmedCoinbase:
      case TransactionType.UnconfirmedCoinbase:
        return tx.amountCredited;
      case TransactionType.Unknown:
        // For Unknown transactions, check if it's an outgoing tx
        // (has debited amount, meaning spending).
        print("DEBUG: Unknown tx - debited=$debited, credited=$credited");
        if (debited > 0) {
          // Outgoing transaction: show net amount (debited - credited = sent + fee).
          final netAmount = debited - credited;
          print("DEBUG: Outgoing Unknown - returning net: $netAmount");
          return netAmount.toString();
        }
        // Otherwise treat as incoming.
        print("DEBUG: Incoming Unknown - returning credited: ${tx.amountCredited}");
        return tx.amountCredited;
    }
  }

  bool _isOutgoingUnknown(Transaction tx) {
    if (tx.txType != TransactionType.Unknown) return false;
    final debited = int.tryParse(tx.amountDebited) ?? 0;
    return debited > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
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
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No transactions yet'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _transactions!.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions![index];
                        final txType = _formatTxType(tx);
                        final statusColor = _getStatusColor(tx);
                        final icon = _getTxIcon(tx);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.2),
                              child: Icon(icon, color: statusColor),
                            ),
                            title: Text(
                              txType,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            subtitle: Text(
                              'Amount: ${_formatAmount(_getDisplayAmount(tx))} EPIC',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _detailRow('ID', tx.id.toString()),
                                    _detailRow('Credited',
                                        '${_formatAmount(tx.amountCredited)} EPIC'),
                                    _detailRow('Debited',
                                        '${_formatAmount(tx.amountDebited)} EPIC'),
                                    _detailRow('Fee',
                                        '${_formatAmount(tx.fee ?? "0")} EPIC'),
                                    _detailRow('Confirmed',
                                        tx.confirmed ? 'Yes' : 'No'),
                                    if (tx.confirmationTs.isNotEmpty)
                                      _detailRow('Confirmation Time',
                                          tx.confirmationTs),
                                    if (tx.creationTs.isNotEmpty)
                                      _detailRow('Creation Time',
                                          tx.creationTs),
                                    if (tx.txSlateId != null)
                                      _copyableDetailRow(context, 'Slate ID',
                                          tx.txSlateId!),
                                    const SizedBox(height: 8),
                                    _detailRow('Number of Inputs',
                                        tx.numInputs.toString()),
                                    _detailRow('Number of Outputs',
                                        tx.numOutputs.toString()),
                                    if (tx.messages?.messages != null &&
                                        tx.messages!.messages.isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Messages:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          ...tx.messages!.messages.map((msg) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(left: 16, top: 4),
                                              child: Text(
                                                '• ${msg.message ?? "No message"}',
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    if (_canCancelTransaction(tx))
                                      Column(
                                        children: [
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 8),
                                          if (_cancelling.contains(tx.id))
                                            const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Text('Cancelling transaction...'),
                                              ],
                                            )
                                          else
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _cancelTransaction(tx),
                                              icon: const Icon(Icons.cancel),
                                              label: const Text(
                                                  'Cancel This Transaction'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                                minimumSize:
                                                    const Size(double.infinity, 45),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'This transaction is pending. Cancel to unlock funds.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _copyableDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

