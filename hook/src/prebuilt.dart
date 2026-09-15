import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

import 'source_fingerprint.dart';

typedef ManifestPin = ({Uri url, String sha256});
typedef _Library = ({String file, String sha256, int size});
const _maximumBytes = 2 * 1024 * 1024 * 1024;
const _timeout = Duration(seconds: 30);

ManifestPin? prebuiltManifest(BuildInput input) {
  final defines = input.userDefines;
  final mode = defines['native_build'] ?? 'source';
  if (mode != 'source' && mode != 'prebuilt') {
    throw FormatException('native_build must be source or prebuilt.');
  }
  if (mode == 'source') return null;
  final url = defines['prebuilt_manifest_url'];
  if (url is! String) throw FormatException('Missing prebuilt_manifest_url.');
  final uri = Uri.parse(url);
  _requireHttps(uri);
  return (url: uri, sha256: _digest(defines['prebuilt_manifest_sha256']));
}

String _digest(Object? value) {
  if (value is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)) {
    throw FormatException('Expected a SHA-256 digest (64 hex characters).');
  }
  return value.toLowerCase();
}

void _requireHttps(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw FormatException(
      'Prebuilt URLs require HTTPS without credentials or fragments.',
    );
  }
}

_Library _library(Object? value, String name) {
  if (value is! Map<String, dynamic> || value['file'] != name) {
    throw FormatException('Expected prebuilt library basename: $name');
  }
  final size = value['size'];
  if (size is! int || size <= 0 || size > _maximumBytes) {
    throw FormatException('Invalid prebuilt size for $name.');
  }
  return (file: name, sha256: _digest(value['sha256']), size: size);
}

List<_Library> _select(
  Object? manifest,
  CodeConfig code,
  String target,
  String walletName,
  String sourceHash,
) {
  if (manifest is! Map<String, dynamic> ||
      manifest['schema_version'] != 1 ||
      manifest['package'] != 'flutter_libepiccash') {
    throw FormatException('Unsupported flutter_libepiccash manifest.');
  }
  if (_digest(manifest['source_sha256']) != sourceHash) {
    throw StateError(
      'Prebuilt source fingerprint mismatch. Use a matching release or native_build: source.',
    );
  }
  final entries = manifest['artifacts'];
  if (entries is! List ||
      entries.any((entry) => entry is! Map<String, dynamic>)) {
    throw FormatException('Manifest artifacts must be a list of objects.');
  }
  final matches = entries
      .cast<Map<String, dynamic>>()
      .where(
        (entry) => entry['target'] == target && entry['link_mode'] == 'dynamic',
      )
      .toList();
  if (matches.length != 1) {
    throw StateError('Expected exactly one dynamic prebuilt for $target.');
  }
  final entry = matches.single;
  final minimum = switch (code.targetOS) {
    OS.android => code.android.targetNdkApi,
    // Keep the existing source hook floor; Flutter can still report iOS 13.
    OS.iOS => code.iOS.targetVersion < 15 ? 15 : code.iOS.targetVersion,
    OS.macOS => code.macOS.targetVersion,
    _ => null,
  };
  if (minimum != null) {
    final required = entry['minimum_os_version'];
    if (required is! int || required <= 0) {
      throw FormatException('Missing minimum_os_version for $target.');
    }
    if (required > minimum) {
      throw UnsupportedError(
        'Prebuilt requires OS/API $required; app targets $minimum.',
      );
    }
  }
  if (code.targetOS == OS.linux) {
    final glibc = entry['minimum_glibc_version'];
    if (glibc is! String || !RegExp(r'^\d+\.\d+$').hasMatch(glibc)) {
      throw FormatException(
        'Linux prebuilt must declare minimum_glibc_version.',
      );
    }
  }
  final android = code.targetOS == OS.android;
  final dependencies = entry['dependencies'] ?? <Object?>[];
  if (dependencies is! List || dependencies.length != (android ? 1 : 0)) {
    throw FormatException(
      'Expected ${android ? 'one Android runtime' : 'no runtime dependencies'} for $target.',
    );
  }
  return [
    _library(entry, walletName),
    if (android) _library(dependencies.single, 'libc++_shared-$target.so'),
  ];
}

/// Return a verified directory for the existing bundler; the caller deletes it.
Future<Directory> downloadPrebuilt(
  BuildInput input,
  BuildOutputBuilder output,
  ManifestPin pin, {
  required String target,
  required String walletName,
}) async {
  final code = input.config.code;
  if (code.sanitizer != null ||
      code.linkModePreference == LinkModePreference.static) {
    throw UnsupportedError(
      'Prebuilts require dynamic linking without sanitizers.',
    );
  }
  if (code.targetOS == OS.iOS &&
      code.iOS.targetSdk == IOSSdk.iPhoneOS &&
      code.targetArchitecture != Architecture.arm64) {
    throw UnsupportedError('iOS device prebuilts require arm64.');
  }
  final source = await sourceFingerprint(input.packageRoot);
  output.dependencies.addAll(source.dependencies);
  final outputDirectory = Directory.fromUri(input.outputDirectory);
  await outputDirectory.create(recursive: true);
  final directory = await outputDirectory.createTemp('.prebuilt-');
  final client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = _timeout;
  try {
    final manifest = File.fromUri(directory.uri.resolve('manifest.json'));
    await _download(
      client,
      pin.url,
      manifest,
      pin.sha256,
      maximum: 1024 * 1024,
    );
    final libraries = _select(
      jsonDecode(await manifest.readAsString()),
      code,
      target,
      walletName,
      source.sha256,
    );
    for (final library in libraries) {
      await _download(
        client,
        pin.url.resolve(library.file),
        File.fromUri(directory.uri.resolve(library.file)),
        library.sha256,
        size: library.size,
      );
    }
    return directory;
  } catch (_) {
    await directory.delete(recursive: true);
    rethrow;
  } finally {
    client.close(force: true);
  }
}

Future<void> _download(
  HttpClient client,
  Uri url,
  File file,
  String digest, {
  int? size,
  int maximum = _maximumBytes,
}) async {
  final transfer = _transfer(client, url, file, size ?? maximum);
  try {
    await transfer.timeout(const Duration(minutes: 10));
  } on TimeoutException {
    // Stop disk/network I/O before removing partial downloads on Windows.
    client.close(force: true);
    try {
      await transfer;
    } catch (_) {
      /* Preserve the timeout. */
    }
    rethrow;
  }
  if ((size != null && await file.length() != size) ||
      (await sha256.bind(file.openRead()).first).toString() != digest) {
    throw StateError('Prebuilt integrity check failed: $url');
  }
}

Future<void> _transfer(
  HttpClient client,
  Uri uri,
  File file,
  int maximum,
) async {
  for (var redirects = 0; redirects <= 5; redirects++) {
    _requireHttps(uri);
    final request = await client.getUrl(uri).timeout(_timeout);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close().timeout(_timeout);
    if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.listen(null).cancel();
      if (location == null) {
        throw HttpException('Prebuilt redirect has no Location.');
      }
      uri = uri.resolve(location);
      continue;
    }
    if (response.statusCode != HttpStatus.ok ||
        response.contentLength > maximum) {
      await response.listen(null).cancel();
      throw HttpException(
        'Invalid prebuilt response: HTTP ${response.statusCode}, length ${response.contentLength}.',
        uri: uri,
      );
    }
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final bytes in response.timeout(_timeout)) {
        received += bytes.length;
        if (received > maximum) {
          throw StateError('Prebuilt exceeds expected size.');
        }
        sink.add(bytes);
        await sink.flush();
      }
    } finally {
      await sink.close();
    }
    return;
  }
  throw HttpException('Too many prebuilt redirects.');
}
