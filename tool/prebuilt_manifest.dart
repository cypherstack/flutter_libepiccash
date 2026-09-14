import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../hook/src/source_fingerprint.dart';

const releaseTargets = <String, int?>{
  'aarch64-linux-android': 24,
  'armv7-linux-androideabi': 24,
  'x86_64-linux-android': 24,
  'aarch64-apple-ios': 15,
  'aarch64-apple-ios-sim': 15,
  'x86_64-apple-ios': 15,
  'aarch64-unknown-linux-gnu': null,
  'x86_64-unknown-linux-gnu': null,
  'aarch64-apple-darwin': 12,
  'x86_64-apple-darwin': 12,
  'x86_64-pc-windows-msvc': null,
};

String releaseFileName(String target) {
  if (!releaseTargets.containsKey(target)) {
    throw ArgumentError.value(target, 'target', 'Unsupported release target');
  }
  final extension = target.contains('apple')
      ? 'dylib'
      : target.contains('windows')
          ? 'dll'
          : 'so';
  return 'libepic_cash_wallet-$target.$extension';
}

Future<String> fileSha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// Read the actual required symbol versions; do not guess from the build host.
Future<String> minimumGlibc(File file) async {
  final result = await Process.run('readelf', ['--version-info', file.path]);
  if (result.exitCode != 0) {
    throw StateError('readelf failed for ${file.path}: ${result.stderr}');
  }
  final versions = RegExp(r'Name: GLIBC_(\d+)\.(\d+)\b')
      .allMatches(result.stdout as String)
      .map((match) => (int.parse(match[1]!), int.parse(match[2]!)))
      .toList()
    ..sort(
      (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
    );
  if (versions.isEmpty) {
    throw StateError('No required glibc symbol versions in ${file.path}');
  }
  final version = versions.last;
  return '${version.$1}.${version.$2}';
}

/// Add a manifest to the existing release directory. All targets are required.
Future<Map<String, Object?>> writeManifest(
  Directory directory, {
  Future<String> Function(File) inspectGlibc = minimumGlibc,
}) async {
  final manifestFile = File.fromUri(directory.uri.resolve('manifest.json'));
  final pinFile = File.fromUri(directory.uri.resolve('manifest.sha256'));
  if (await manifestFile.exists() || await pinFile.exists()) {
    throw StateError('Manifest output already exists.');
  }
  Future<Map<String, Object>> describe(String name) async {
    final file = File.fromUri(directory.uri.resolve(name));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Missing or nonregular release artifact: $name');
    }
    final size = await file.length();
    if (size <= 0 || size > 2 * 1024 * 1024 * 1024) {
      throw StateError('Invalid release artifact size: $name');
    }
    return {'file': name, 'size': size, 'sha256': await fileSha256(file)};
  }

  final artifacts = <Map<String, Object?>>[];
  final targets = releaseTargets.keys.toList()..sort();
  for (final target in targets) {
    final name = releaseFileName(target);
    artifacts.add({
      'target': target,
      'link_mode': 'dynamic',
      ...await describe(name),
      if (releaseTargets[target] case final int minimum)
        'minimum_os_version': minimum,
      if (target.endsWith('linux-gnu'))
        'minimum_glibc_version': await inspectGlibc(
          File.fromUri(directory.uri.resolve(name)),
        ),
      if (target.contains('android'))
        'dependencies': [await describe('libc++_shared-$target.so')],
    });
  }
  final source = await sourceFingerprint(Directory.current.uri);
  final manifest = <String, Object?>{
    'schema_version': 1,
    'package': 'flutter_libepiccash',
    'source_sha256': source.sha256,
    'artifacts': artifacts,
  };
  await manifestFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  await pinFile.writeAsString(
    '${await fileSha256(manifestFile)}  manifest.json\n',
  );
  return manifest;
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: prebuilt_manifest.dart <release-artifacts-directory>',
    );
    exitCode = 64;
    return;
  }
  await writeManifest(Directory(args.single).absolute);
}
