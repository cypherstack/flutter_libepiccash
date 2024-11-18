import 'package:flutter/material.dart';

import 'wallet_management_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_libepiccash/example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WalletManagementView(),
    );
  }
}
