import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libepiccash/epic_cash.dart';
import 'package:flutter_libepiccash_example/init_transaction_view.dart';

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

class _WalletInfoViewState extends State<WalletInfoView> {
  String _resultMessage = "";
  bool _isLoading = false;
  String? _walletConfig;

  @override
  void initState() {
    super.initState();
    _loadWalletConfig();
  }

  Future<void> _loadWalletConfig() async {
    try {
      final config = await EpicboxConfig.getDefaultConfig(widget.walletName);
      setState(() {
        _walletConfig = config;
      });
    } catch (e) {
      setState(() {
        _resultMessage = "Error loading wallet config: $e";
      });
    }
  }

  Future<void> _getAddressInfo() async {
    if (_walletConfig == null) return;

    setState(() {
      _isLoading = true;
      _resultMessage = "";
    });

    try {
      final walletResult = openWallet(_walletConfig!, widget.password);
      if (walletResult.contains('Error')) {
        setState(() {
          _resultMessage = 'Error opening wallet: $walletResult';
        });
        return;
      }

      final epicboxConfig =
          await EpicboxConfig.getDefaultConfig(widget.walletName);
      final address = getAddressInfo(walletResult, 0, epicboxConfig);
      setState(() {
        _resultMessage = "Address Info: $address";
      });
    } catch (e) {
      setState(() {
        _resultMessage = "Error retrieving address info: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getChainHeight() async {
    if (_walletConfig == null) return;

    setState(() {
      _isLoading = true;
      _resultMessage = "";
    });

    try {
      final height = getChainHeight(_walletConfig!);
      setState(() {
        _resultMessage = "Chain Height: $height";
      });
    } catch (e) {
      setState(() {
        _resultMessage = "Error retrieving chain height: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanOutputs() async {
    if (_walletConfig == null) return;

    setState(() {
      _isLoading = true;
      _resultMessage = "";
    });

    try {
      final result = await scanOutPuts(_walletConfig!, 0, 100);
      setState(() {
        _resultMessage = "Scan Outputs Result: $result";
      });
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Wallet: ${widget.walletName}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
        body: FutureBuilder<String>(
          future: EpicboxConfig.getDefaultConfig(widget.walletName),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final config = snapshot.data!;
            return FutureBuilder<String>(
              future: _getWalletAddress(config),
              builder: (context, addressSnapshot) {
                if (addressSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet Address:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                addressSnapshot.data ?? 'Error getting address',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                  text: addressSnapshot.data ?? '',
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Address copied to clipboard'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => InitTransactionView(
                                        password: widget.password),
                                  ),
                                );
                              },
                              child: const Text('Initiate Transaction'),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _getAddressInfo,
                              child: const Text('Get Address Info'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _getChainHeight,
                              child: const Text('Get Chain Height'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _scanOutputs,
                              child: const Text('Scan Outputs'),
                            ),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            if (_resultMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  _resultMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<String> _getWalletAddress(String config) async {
    try {
      final walletResult = openWallet(config, widget.password);
      if (walletResult.contains('Error')) {
        return 'Error opening wallet: $walletResult';
      }

      final epicboxConfig =
          await EpicboxConfig.getDefaultConfig(widget.walletName);
      final address = getAddressInfo(walletResult, 0, epicboxConfig);
      return address;
    } catch (e) {
      return 'Error getting address: $e';
    }
  }
}
