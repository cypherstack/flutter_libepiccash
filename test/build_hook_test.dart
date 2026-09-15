import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks/hooks.dart';

import '../hook/build.dart' as hook;
import '../hook/src/prebuilt.dart';
import '../hook/src/source_fingerprint.dart';
import '../tool/prebuilt_manifest.dart';

void main() {
  late Directory workspace;
  late Directory artifacts;
  late Map<String, Object?> manifest;
  late Map<String, List<int>> responses;
  late HttpServer server;
  late List<String> requests;
  late List<_LoopbackClient> clients;
  int status = 200;
  String? redirect;
  bool stall = false;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('epic-prebuilt-');
    artifacts = await Directory.fromUri(workspace.uri.resolve('artifacts/'))
        .create();
    responses = {};
    for (final target in releaseTargets.keys) {
      for (final name in [
        releaseFileName(target),
        if (target.contains('android')) 'libc++_shared-$target.so',
      ]) {
        final bytes = utf8.encode('fixture $name');
        responses[name] = bytes;
        await File.fromUri(artifacts.uri.resolve(name)).writeAsBytes(bytes);
      }
    }
    manifest = await writeManifest(
      artifacts,
      inspectGlibc: (_) async => '2.35',
    );
    requests = [];
    clients = [];
    status = 200;
    redirect = null;
    stall = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final name = request.uri.pathSegments.last;
      requests.add(name);
      request.response.statusCode = status;
      if (redirect != null) {
        request.response.headers.set(HttpHeaders.locationHeader, redirect!);
      }
      request.response.bufferOutput = !stall;
      request.response.add(
        responses[name] ?? utf8.encode(jsonEncode(manifest)),
      );
      if (stall) {
        unawaited(request.response.done.catchError((_) {}));
      } else {
        await request.response.close();
      }
    });
  });

  tearDown(() async {
    for (final client in clients) {
      client.close(force: true);
    }
    await server.close(force: true);
    await workspace.delete(recursive: true);
  });

  Future<void> run({
    OS os = OS.macOS,
    Architecture arch = Architecture.arm64,
    IOSSdk sdk = IOSSdk.iPhoneOS,
    int minimum = 24,
    LinkModePreference linkMode = LinkModePreference.dynamic,
    Map<String, Object?> settings = const {},
    Future<void> Function(BuildInput, BuildOutput)? check,
  }) async {
    // Construct outside HttpOverrides so the delegate remains a real client.
    final client = _LoopbackClient(server.port);
    clients.add(client);
    await testCodeBuildHook(
      mainMethod: (args) => HttpOverrides.runZoned(
        () => hook.main(args),
        createHttpClient: (_) => client,
      ),
      targetOS: os,
      targetArchitecture: arch,
      targetIOSSdk: sdk,
      targetAndroidNdkApi: minimum,
      targetIOSVersion: minimum,
      targetMacOSVersion: minimum,
      linkModePreference: linkMode,
      userDefines: PackageUserDefines(
        workspacePubspec: PackageUserDefinesSource(
          basePath: workspace.uri,
          defines: {
            'native_build': 'prebuilt',
            'prebuilt_manifest_url': 'https://release.invalid/manifest.json',
            'prebuilt_manifest_sha256': sha256
                .convert(utf8.encode(jsonEncode(manifest)))
                .toString(),
            ...settings,
          },
        ),
      ),
      check: (input, output) async {
        // Temporary downloads must not become hook dependencies or survive a run.
        expect(
          output.dependencies.any((uri) => uri.path.contains('.prebuilt-')),
          isFalse,
        );
        expect(
          Directory.fromUri(input.outputDirectory)
              .listSync()
              .whereType<Directory>(),
          isEmpty,
        );
        await check?.call(input, output);
      },
    );
  }

  Map<String, Object?> entry(String target) => (manifest['artifacts'] as List)
      .cast<Map<String, Object?>>()
      .singleWhere((entry) => entry['target'] == target);

  test(
    'producer hashes all wallets and Android runtimes and pins the manifest',
    () async {
      final entries = (manifest['artifacts'] as List)
          .cast<Map<String, Object?>>();
      expect(entries, hasLength(11));
      for (final entry in entries) {
        for (final file in [
          entry,
          ...?entry['dependencies'] as List<Map<String, Object>>?,
        ]) {
          final bytes = responses[file['file']]!;
          expect(file['size'], bytes.length);
          expect(file['sha256'], sha256.convert(bytes).toString());
        }
      }
      final document = File.fromUri(artifacts.uri.resolve('manifest.json'));
      expect(jsonDecode(await document.readAsString()), manifest);
      expect(
        await File.fromUri(artifacts.uri.resolve('manifest.sha256'))
            .readAsString(),
        '${await fileSha256(document)}  manifest.json\n',
      );
      await expectLater(writeManifest(artifacts), throwsStateError);
      await document.delete();
      await File.fromUri(artifacts.uri.resolve('manifest.sha256')).delete();
      await File.fromUri(
        artifacts.uri.resolve('libc++_shared-aarch64-linux-android.so'),
      ).delete();
      await expectLater(
        writeManifest(artifacts, inspectGlibc: (_) async => '2.35'),
        throwsStateError,
      );
      expect(await document.exists(), isFalse);
    },
  );

  for (final target in [
    (
      OS.macOS,
      Architecture.arm64,
      IOSSdk.iPhoneOS,
      'aarch64-apple-darwin',
      'libepic_cash_wallet.dylib',
    ),
    (
      OS.windows,
      Architecture.x64,
      IOSSdk.iPhoneOS,
      'x86_64-pc-windows-msvc',
      'epic_cash_wallet.dll',
    ),
    (
      OS.linux,
      Architecture.x64,
      IOSSdk.iPhoneOS,
      'x86_64-unknown-linux-gnu',
      'libepic_cash_wallet.so',
    ),
    (
      OS.iOS,
      Architecture.arm64,
      IOSSdk.iPhoneOS,
      'aarch64-apple-ios',
      'libepic_cash_wallet.dylib',
    ),
    (
      OS.iOS,
      Architecture.arm64,
      IOSSdk.iPhoneSimulator,
      'aarch64-apple-ios-sim',
      'libepic_cash_wallet.dylib',
    ),
    (
      OS.iOS,
      Architecture.x64,
      IOSSdk.iPhoneSimulator,
      'x86_64-apple-ios',
      'libepic_cash_wallet.dylib',
    ),
    (
      OS.android,
      Architecture.arm,
      IOSSdk.iPhoneOS,
      'armv7-linux-androideabi',
      'libepic_cash_wallet.so',
    ),
    (
      OS.android,
      Architecture.arm64,
      IOSSdk.iPhoneOS,
      'aarch64-linux-android',
      'libepic_cash_wallet.so',
    ),
    (
      OS.android,
      Architecture.x64,
      IOSSdk.iPhoneOS,
      'x86_64-linux-android',
      'libepic_cash_wallet.so',
    ),
  ]) {
    test('downloads and bundles ${target.$4} through the build hook', () async {
      for (var attempt = 0; attempt < 2; attempt++) {
        await run(
          os: target.$1,
          arch: target.$2,
          sdk: target.$3,
          minimum: target.$1 == OS.iOS ? 13 : 24,
          check: (input, output) async {
            final assets = {
              for (final asset in output.assets.code)
                asset.file!.pathSegments.last: asset,
            };
            expect(
              assets.keys,
              unorderedEquals([
                target.$5,
                if (target.$1 == OS.android) 'libc++_shared.so',
              ]),
            );
            final wallet = assets[target.$5]!;
            expect(
              wallet.id,
              'package:flutter_libepiccash/src/epic_cash_wallet_bindings.g.dart',
            );
            expect(wallet.linkMode, isA<DynamicLoadingBundled>());
            expect(
              await File.fromUri(wallet.file!).readAsBytes(),
              responses[releaseFileName(target.$4)],
            );
            if (target.$1 == OS.android) {
              final runtime = assets['libc++_shared.so']!;
              expect(
                runtime.id,
                'package:flutter_libepiccash/libc++_shared.so',
              );
              expect(
                await File.fromUri(runtime.file!).readAsBytes(),
                responses['libc++_shared-${target.$4}.so'],
              );
            }
          },
        );
      }
      expect(requests, [
        for (var i = 0; i < 2; i++) ...[
          'manifest.json',
          releaseFileName(target.$4),
          if (target.$1 == OS.android) 'libc++_shared-${target.$4}.so',
        ],
      ]);
    });
  }

  for (final mode in [null, 'source']) {
    test('selects source builds with native_build: $mode', () async {
      await testCodeBuildHook(
        mainMethod: (args) => build(args, (input, output) async {
          expect(prebuiltManifest(input), isNull);
        }),
        userDefines: PackageUserDefines(
          workspacePubspec: PackageUserDefinesSource(
            basePath: workspace.uri,
            defines: {'native_build': ?mode},
          ),
        ),
        check: (_, _) {},
      );
      expect(requests, isEmpty);
    });
  }

  for (final settings in <Map<String, Object?>>[
    {'native_build': 'invalid'},
    {'prebuilt_manifest_url': 'http://release.invalid/manifest.json'},
    {
      'prebuilt_manifest_url':
          'https://user:pass@release.invalid/manifest.json',
    },
    {'prebuilt_manifest_sha256': null},
    {'prebuilt_manifest_sha256': 'g' * 64},
  ]) {
    test('rejects invalid configuration: $settings', () async {
      await expectLater(run(settings: settings), throwsFormatException);
      expect(requests, isEmpty);
    });
  }

  for (final file in [
    'manifest.json',
    'libepic_cash_wallet-aarch64-linux-android.so',
    'libc++_shared-aarch64-linux-android.so',
  ]) {
    test('fails closed for corrupted $file', () async {
      responses[file] = [1];
      await expectLater(run(os: OS.android), throwsStateError);
      expect(requests.last, file);
    });
  }

  test('rejects oversized downloads and HTTP errors', () async {
    final wallet = releaseFileName('aarch64-apple-darwin');
    responses[wallet] = List.filled(responses[wallet]!.length + 1, 42);
    await expectLater(run(), throwsStateError);
    status = 404;
    await expectLater(run(), throwsA(isA<HttpException>()));
  });

  test('follows HTTPS redirects but rejects downgrades and loops', () async {
    status = 302;
    redirect = 'https://release.invalid/loop';
    await expectLater(run(), throwsA(isA<HttpException>()));
    expect(requests, hasLength(6));
    requests.clear();
    redirect = 'http://release.invalid/insecure';
    await expectLater(run(), throwsFormatException);
    expect(requests, ['manifest.json']);
  });

  test('cancels timed-out downloads before cleanup', () async {
    stall = true;
    await runZoned(
      () => expectLater(run(), throwsA(isA<TimeoutException>())),
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          return parent.createTimer(
            zone,
            duration == const Duration(minutes: 10)
                ? const Duration(milliseconds: 100)
                : duration,
            callback,
          );
        },
      ),
    );
    expect(clients.single.forceClosed, isTrue);
  });

  for (final mutate in <String, void Function()>{
    'source mismatch': () => manifest['source_sha256'] = '0' * 64,
    'wrong package': () => manifest['package'] = 'other',
    'duplicate target': () =>
        (manifest['artifacts'] as List).add(entry('aarch64-apple-darwin')),
    'path traversal': () =>
        entry('aarch64-apple-darwin')['file'] = '../outside.dylib',
    'missing OS floor': () =>
        entry('aarch64-apple-darwin').remove('minimum_os_version'),
    'missing Android runtime': () =>
        entry('aarch64-linux-android').remove('dependencies'),
  }.entries) {
    test('rejects manifest ${mutate.key}', () async {
      mutate.value();
      await expectLater(
        run(os: mutate.key.contains('Android') ? OS.android : OS.macOS),
        throwsA(anything),
      );
      expect(requests, ['manifest.json']);
    });
  }

  test('checks deployment minimums and required static linking', () async {
    await expectLater(run(os: OS.android, minimum: 23), throwsUnsupportedError);
    await expectLater(
      run(linkMode: LinkModePreference.static),
      throwsUnsupportedError,
    );
    await expectLater(
      run(os: OS.iOS, arch: Architecture.x64),
      throwsUnsupportedError,
    );
    await run(linkMode: LinkModePreference.preferStatic);
  });

  test(
    'fingerprints detect native edits, additions, renames, and symlinks',
    () async {
      final root = Directory.fromUri(workspace.uri.resolve('source/'));
      for (final path in [
        'rust/Cargo.toml',
        'rust/Cargo.lock',
        'rust/rust-toolchain.toml',
        'rust/build.rs',
        'rust/cbindgen.toml',
        'rust/src/lib.rs',
        'rust/include/epic_cash_wallet.h',
        'lib/src/epic_cash_wallet_bindings.g.dart',
        'hook/build.dart',
      ]) {
        final file = File.fromUri(root.uri.resolve(path));
        await file.parent.create(recursive: true);
        await file.writeAsString('fixture: $path');
      }
      var fingerprint = await sourceFingerprint(root.uri);
      for (final change in <Future<void> Function()>[
        () async {
          await File.fromUri(root.uri.resolve('rust/build.rs'))
              .writeAsString('changed');
        },
        () async {
          await File.fromUri(root.uri.resolve('rust/src/new.rs'))
              .writeAsString('new');
        },
        () async {
          await File.fromUri(root.uri.resolve('rust/src/new.rs'))
              .rename(root.uri.resolve('rust/src/renamed.rs').toFilePath());
        },
      ]) {
        await change();
        final changed = await sourceFingerprint(root.uri);
        expect(changed.sha256, isNot(fingerprint.sha256));
        fingerprint = changed;
      }
      expect(fingerprint.dependencies, contains(root.uri.resolve('rust/src/')));
      if (!Platform.isWindows) {
        await Link.fromUri(root.uri.resolve('rust/src/link.rs'))
            .create(root.uri.resolve('rust/build.rs').toFilePath());
        await expectLater(sourceFingerprint(root.uri), throwsStateError);
      }
    },
  );
}

// Route HTTPS test requests to loopback without weakening production URL checks.
class _LoopbackClient implements HttpClient {
  final int port;
  final HttpClient delegate = HttpClient();
  bool forceClosed = false;
  _LoopbackClient(this.port);
  @override
  Future<HttpClientRequest> getUrl(Uri url) => delegate.getUrl(
    url.replace(scheme: 'http', host: '127.0.0.1', port: port),
  );
  @override
  set connectionTimeout(Duration? value) => delegate.connectionTimeout = value;
  @override
  set autoUncompress(bool value) => delegate.autoUncompress = value;
  @override
  void close({bool force = false}) {
    forceClosed |= force;
    delegate.close(force: force);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
