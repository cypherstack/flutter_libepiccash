import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Create a folder for a wallet in the "wallets" directory.
Future<String> createFolder(String folderName) async {
  try {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String walletsPath =
        '${appDocDir.path}/flutter_libepiccash/example/wallets';
    final walletsDir = Directory(walletsPath);

    if (!await walletsDir.exists()) {
      await walletsDir.create(recursive: true);
    }

    final walletDir = Directory('$walletsPath/$folderName');

    if (await walletDir.exists()) {
      return "directory_exists";
    } else {
      final Directory newFolder = await walletDir.create(recursive: true);
      return newFolder.path;
    }
  } catch (e) {
    print("Error creating wallet folder: $e");
    return "error";
  }
}
