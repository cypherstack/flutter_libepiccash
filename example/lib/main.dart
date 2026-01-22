import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'wallet_management_view.dart';

void main() {
  // Catch Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    developer.log(
      'Flutter Error',
      name: 'flutter_libepiccash_example',
      error: details.exception,
      stackTrace: details.stack,
    );
    print('Exception: ${details.exception}');
    print('Stack trace:\n${details.stack}');
  };

  // Catch async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log(
      'Async Error',
      name: 'flutter_libepiccash_example',
      error: error,
      stackTrace: stack,
    );
    print('Error: $error');
    print('Stack trace:\n$stack');
    return true;
  };

  // Run app with error handling
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const MyApp());
    },
    (error, stack) {
      developer.log(
        'Zone Error',
        name: 'flutter_libepiccash_example',
        error: error,
        stackTrace: stack,
      );
      print('Error: $error');
      print('Stack trace:\n$stack');
    },
  );
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
