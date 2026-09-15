import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

/// Shared by the build hook and release tooling. Include paths as well as bytes
/// so moving, adding, or deleting native sources invalidates a release.
Future<({String sha256, List<Uri> dependencies})> sourceFingerprint(
  Uri packageRoot,
) async {
  final files = <String, File>{};
  final dependencies = <Uri>[];
  for (final path in [
    'rust/Cargo.toml',
    'rust/Cargo.lock',
    'rust/rust-toolchain.toml',
    'lib/src/epic_cash_wallet_bindings.g.dart',
    'rust/build.rs',
    'rust/cbindgen.toml',
    'hook/build.dart',
  ]) {
    files[path] = File.fromUri(packageRoot.resolve(path));
  }
  for (final path in ['rust/src/', 'rust/include/']) {
    final directory = Directory.fromUri(packageRoot.resolve(path));
    if (await FileSystemEntity.isLink(directory.path)) {
      throw StateError('Prebuilt source inputs cannot be symlinks: $path');
    }
    dependencies.add(directory.uri);
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Link) {
        throw StateError(
          'Prebuilt source inputs cannot be symlinks: ${entity.path}',
        );
      }
      if (entity is Directory) dependencies.add(entity.uri);
      if (entity is File) {
        final relative = entity.uri.path.substring(packageRoot.path.length);
        files[Uri.decodeComponent(relative)] = entity;
      }
    }
  }
  final paths = files.keys.toList()..sort();
  final framed = StringBuffer();
  for (final path in paths) {
    final file = files[path]!;
    if (await FileSystemEntity.isLink(file.path)) {
      throw StateError('Prebuilt source inputs cannot be symlinks: $path');
    }
    final digest = await crypto.sha256.bind(file.openRead()).first;
    framed.write('$path\u0000$digest\n');
    dependencies.add(file.uri);
  }
  return (
    sha256: crypto.sha256.convert(utf8.encode(framed.toString())).toString(),
    dependencies: dependencies,
  );
}
