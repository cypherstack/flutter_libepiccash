import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libepiccash/lib.dart';
import 'package:flutter_libepiccash_example/send_transaction_view.dart';
import 'package:flutter_libepiccash_example/transaction_view.dart';
import 'package:flutter_libepiccash_example/wallet_state_manager.dart';

import 'epicbox_config.dart';

class WalletInfoView extends StatefulWidget {
  final String walletName;
  final String password;

  const WalletInfoView({
    Key? key,
    required this.walletName,
    required this.password,
  }) : super(key: key);

  @override
  State<WalletInfoView> createState() => _WalletInfoViewState();
}

class _WalletInfoViewState extends State<WalletInfoView>
    with WidgetsBindingObserver {
  String _resultMessage = "";
  bool _isLoading = false;
  String? _walletConfig;
  String? _wallet;
  String? _epicboxConfig;
  bool _listenerRunning = false;

  // Timer for polling listener health.
  Timer? _listenerHealthTimer;
  static const _healthCheckInterval = Duration(seconds: 20);

  // Balance info.
  double _totalBalance = 0.0;
  double _spendableBalance = 0.0;
  double _pendingBalance = 0.0;
  double _awaitingFinalizationBalance = 0.0;

  // Sync info.
  int _lastScannedBlock = 0;
  int _chainHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWalletConfig();
    _startHealthCheckTimer();
  }

  @override
  void dispose() {
    _listenerHealthTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Note: We do NOT stop the listener here - it keeps running when navigating away.
    // The listener is only stopped on app close (see didChangeAppLifecycleState).
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop ALL listeners when app goes to background or is terminated.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      LibEpiccash.stopAllEpicboxListeners();
      setState(() {
        _listenerRunning = false;
      });
    }
  }

  void _startHealthCheckTimer() {
    _listenerHealthTimer?.cancel();
    _listenerHealthTimer = Timer.periodic(_healthCheckInterval, (_) {
      _checkListenerHealth();
    });
    // Also check immediately.
    _checkListenerHealth();
  }

  void _checkListenerHealth() {
    final isRunning =
        LibEpiccash.isEpicboxListenerRunning(walletId: widget.walletName);
    if (isRunning != _listenerRunning) {
      setState(() {
        _listenerRunning = isRunning;
        if (!isRunning && _listenerRunning) {
          _resultMessage = "Listener stopped unexpectedly";
        }
      });
    }
  }

  Future<void> _loadWalletConfig() async {
    try {
      final config = await EpicboxConfig.getDefaultConfig(widget.walletName);
      final epicboxConfig = EpicboxConfig.getEpicboxServerConfig();
      final wallet = await LibEpiccash.openWallet(
        config: config,
        password: widget.password,
      );

      // Load last scanned block from storage.
      final lastScanned = await WalletStateManager.getLastScannedBlock(widget.walletName);

      setState(() {
        _walletConfig = config;
        _epicboxConfig = epicboxConfig;
        _wallet = wallet;
        _lastScannedBlock = lastScanned;
      });

      // Get chain height first.
      await _updateChainHeight();

      // Determine wallet state and show appropriate message.
      final defaultHeight = await WalletStateManager.getDefaultStartHeight(widget.walletName);

      if (lastScanned == 0 && defaultHeight == 0) {
        // New wallet - start at chain tip (no scanning needed).
        setState(() {
          _lastScannedBlock = _chainHeight;
          _resultMessage = "New wallet - starting at current chain height $_chainHeight";
        });
        await WalletStateManager.saveLastScannedBlock(widget.walletName, _chainHeight);
      } else if (lastScanned < _chainHeight) {
        // Recovered wallet or wallet with pending scan.
        setState(() {
          _resultMessage = "Recovered wallet - ready to scan from block $_lastScannedBlock to $_chainHeight";
        });
      }

      // Update balance (don't auto-scan).
      await _updateBalance();
    } catch (e) {
      setState(() {
        _resultMessage = "Error loading wallet config: $e";
      });
    }
  }

  Future<void> _refreshAll() async {
    await _updateChainHeight();
    await _updateBalance();
  }

  Future<void> _updateBalance() async {
    if (_wallet == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final balances = await LibEpiccash.getWalletBalances(
        wallet: _wallet!,
        refreshFromNode: 1,
        minimumConfirmations: 10,
      );

      setState(() {
        _totalBalance = balances.total;
        _spendableBalance = balances.spendable;
        _pendingBalance = balances.pending;
        _awaitingFinalizationBalance = balances.awaitingFinalization;
        _resultMessage = "Balance updated successfully";
      });
    } catch (e) {
      setState(() {
        _resultMessage = "Error updating balance: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateChainHeight() async {
    if (_walletConfig == null) return;

    try {
      final height = await LibEpiccash.getChainHeight(config: _walletConfig!);
      setState(() {
        _chainHeight = height;
      });
    } catch (e) {
      setState(() {
        _resultMessage = "Error getting chain height: $e";
      });
    }
  }

  Future<void> _startListener() async {
    if (_wallet == null || _epicboxConfig == null) {
      throw Exception("Wallet or epicbox config not loaded");
    }

    // Check if already running using health check.
    if (LibEpiccash.isEpicboxListenerRunning(walletId: widget.walletName)) {
      setState(() {
        _listenerRunning = true;
        _resultMessage = "Epicbox listener already running for ${widget.walletName}";
      });
      return;
    }

    try {
      LibEpiccash.startEpicboxListener(
        walletId: widget.walletName,
        wallet: _wallet!,
        epicboxConfig: _epicboxConfig!,
      );

      // Immediately verify listener started.
      final isRunning =
          LibEpiccash.isEpicboxListenerRunning(walletId: widget.walletName);
      setState(() {
        _listenerRunning = isRunning;
        _resultMessage = isRunning
            ? "Epicbox listener started for ${widget.walletName}"
            : "Epicbox listener start returned but health check says not running";
      });
    } catch (e) {
      _checkListenerHealth(); // Update state to reflect actual status.
      setState(() {
        _resultMessage = "Error starting listener: $e";
      });
      rethrow;
    }
  }

  void _stopListener() {
    // Check actual status first.
    if (!LibEpiccash.isEpicboxListenerRunning(walletId: widget.walletName)) {
      setState(() {
        _listenerRunning = false;
      });
      return;
    }

    try {
      LibEpiccash.stopEpicboxListener(walletId: widget.walletName);
      // Verify it actually stopped.
      final stillRunning =
          LibEpiccash.isEpicboxListenerRunning(walletId: widget.walletName);
      setState(() {
        _listenerRunning = stillRunning;
        _resultMessage = stillRunning
            ? "Epicbox listener stop called but still running"
            : "Epicbox listener stopped for ${widget.walletName}";
      });
    } catch (e) {
      _checkListenerHealth(); // Update state to reflect actual status.
      setState(() {
        _resultMessage = "Error stopping listener: $e";
      });
    }
  }


  Future<void> _scanOutputs({int? customStartHeight}) async {
    if (_wallet == null) return;

    setState(() {
      _isLoading = true;
      _resultMessage = "Scanning blockchain...";
    });

    try {
      // Use custom start height if provided, otherwise use last scanned block.
      int startHeight = customStartHeight ?? _lastScannedBlock;

      // If chain height is 0 or not yet loaded, fetch it first.
      if (_chainHeight == 0) {
        await _updateChainHeight();
      }

      // If we're starting from 0 and there's a stored default start height, use it.
      if (startHeight == 0 && customStartHeight == null) {
        final defaultStart = await WalletStateManager.getDefaultStartHeight(widget.walletName);
        if (defaultStart > 0) {
          startHeight = defaultStart;
          setState(() {
            _resultMessage = "Starting scan from saved height: $startHeight";
          });
        }
      }

      if (_chainHeight == 0) {
        setState(() {
          _resultMessage = "Unable to get chain height. Check node connection.";
        });
        return;
      }

      if (startHeight >= _chainHeight) {
        setState(() {
          _lastScannedBlock = _chainHeight;
          _resultMessage = "Already synced to tip! (Block $_chainHeight)";
        });
        await WalletStateManager.saveLastScannedBlock(widget.walletName, _chainHeight);
        return;
      }

      // Scan in chunks to avoid timeout.
      final int chunkSize = 10000;

      while (startHeight < _chainHeight) {
        final int blocksToScan = (_chainHeight - startHeight) < chunkSize
            ? (_chainHeight - startHeight)
            : chunkSize;

        setState(() {
          _resultMessage = "Scanning blocks $startHeight to ${startHeight + blocksToScan}...";
        });

        final int scannedHeight = await LibEpiccash.scanOutputs(
          wallet: _wallet!,
          startHeight: startHeight,
          numberOfBlocks: blocksToScan,
        );

        setState(() {
          _lastScannedBlock = scannedHeight;
          _resultMessage = "Scanned to block $scannedHeight / $_chainHeight";
        });

        // Save progress after each chunk.
        await WalletStateManager.saveLastScannedBlock(widget.walletName, scannedHeight);

        if (scannedHeight >= _chainHeight) {
          break;
        }

        startHeight = scannedHeight;
      }

      setState(() {
        _resultMessage = "Scan complete! Synced to block $_lastScannedBlock";
      });

      // Update balance after scanning to show detected outputs.
      await _updateBalance();
    } catch (e) {
      setState(() {
        _resultMessage = "Error scanning outputs: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showStartHeightDialog() async {
    final controller = TextEditingController();
    final defaultHeight = await WalletStateManager.getDefaultStartHeight(widget.walletName);
    if (defaultHeight > 0) {
      controller.text = defaultHeight.toString();
    }

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Scan Start Height'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the block height to start scanning from:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: If your wallet was created recently, you can skip old blocks to speed up scanning.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Start Height',
                hintText: '0',
                helperText: 'Current chain height: $_chainHeight',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Suggested heights:\n'
              '• Jan 1, 2026: ~3,150,000\n'
              '• Dec 1, 2025: ~3,100,000\n'
              '• Jan 1, 2025: ~2,750,000',
              style: TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final height = int.tryParse(controller.text);
              Navigator.pop(context, height);
            },
            child: const Text('Start Scan'),
          ),
        ],
      ),
    );

    if (result != null && result >= 0) {
      // Save this as the default start height for this wallet.
      await WalletStateManager.saveDefaultStartHeight(widget.walletName, result);
      setState(() {
        _lastScannedBlock = result;
      });
      await WalletStateManager.saveLastScannedBlock(widget.walletName, result);

      // Start scanning from this height.
      await _scanOutputs(customStartHeight: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Note: We do NOT stop the listener here - it keeps running across navigation.
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Wallet: ${widget.walletName}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Note: We do NOT stop the listener here - it keeps running across navigation.
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _refreshAll,
            ),
          ],
        ),
        body: _wallet == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Balance Card.
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Balance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _balanceRow('Total', _totalBalance),
                            _balanceRow('Spendable', _spendableBalance),
                            _balanceRow('Pending', _pendingBalance),
                            _balanceRow('Awaiting Finalization',
                                _awaitingFinalizationBalance),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sync Status Card.
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sync Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Chain Height: $_chainHeight'),
                            Text('Last Scanned Block: $_lastScannedBlock'),
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _listenerRunning
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Listener: ${_listenerRunning ? "Running" : "Stopped"}',
                                  style: TextStyle(
                                    color: _listenerRunning
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _checkListenerHealth,
                                  icon: const Icon(Icons.health_and_safety,
                                      size: 16),
                                  label: const Text('Check'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Health check every ${_healthCheckInterval.inSeconds}s',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            // Show all active listeners across all wallets.
                            Builder(
                              builder: (context) {
                                final activeListeners =
                                    LibEpiccash.getActiveListenerWalletIds();
                                if (activeListeners.isEmpty) {
                                  return const Text(
                                    'No active listeners',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  );
                                }
                                return Text(
                                  'Active listeners: ${activeListeners.join(", ")}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.blue),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Wallet Address Card.
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Epicbox Address',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<String>(
                              future: _getWalletAddress(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }
                                final address = snapshot.data ?? 'Error';
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: address));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Address copied to clipboard'),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons.
                    ElevatedButton.icon(
                      onPressed: _listenerRunning ? null : _startListener,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Epicbox Listener'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _listenerRunning ? _stopListener : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Epicbox Listener'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _scanOutputs,
                            icon: const Icon(Icons.sync),
                            label: const Text('Scan from Last Block'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _showStartHeightDialog,
                          icon: const Icon(Icons.settings),
                          label: const Text('Custom Scan'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SendTransactionView(
                              walletName: widget.walletName,
                              password: widget.password,
                              wallet: _wallet!,
                              epicboxConfig: _epicboxConfig!,
                              listenerRunning: _listenerRunning,
                              onStartListener: _startListener,
                            ),
                          ),
                        );
                        // Refresh after sending.
                        await _refreshAll();
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Send Transaction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionView(
                              walletName: widget.walletName,
                              password: widget.password,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('View Transaction History'),
                    ),
                    const SizedBox(height: 16),

                    // Status Message.
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator()),
                    if (_resultMessage.isNotEmpty)
                      Card(
                        color: Colors.blue[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            _resultMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _balanceRow(String label, double value) {
    final epicValue = (value).toStringAsFixed(8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$epicValue EPIC',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<String> _getWalletAddress() async {
    if (_wallet == null || _epicboxConfig == null) {
      return 'Loading...';
    }

    try {
      final address = await LibEpiccash.getAddressInfo(
        wallet: _wallet!,
        index: 0,
        epicboxConfig: _epicboxConfig!,
      );
      return address;
    } catch (e) {
      return 'Error getting address: $e';
    }
  }
}
