import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks/hooks.dart';

import '../hook/build.dart' as hook;

void main() {
  late Directory workspace;
  late Directory prebuiltDirectory;
  late File library;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('epic_hook_test.');
    prebuiltDirectory = await Directory.fromUri(
      workspace.uri.resolve('native assets/epic cash/'),
    ).create(recursive: true);
    library = await File.fromUri(
      prebuiltDirectory.uri.resolve(
        'libepic_cash_wallet-x86_64-unknown-linux-gnu.so',
      ),
    ).writeAsBytes([0, 1, 2, 3]);
  });

  tearDown(() async {
    await workspace.delete(recursive: true);
  });

  for (final absolute in [false, true]) {
    for (final trailingSlash in [false, true]) {
      test(
        'bundles a prebuilt from an ${absolute ? 'absolute' : 'relative'} '
        'directory ${trailingSlash ? 'with' : 'without'} a trailing slash',
        () async {
          final directoryPath = absolute
              ? prebuiltDirectory.path.replaceFirst(RegExp(r'[/\\]+$'), '')
              : 'native assets/epic cash';
          final configuredPath =
              trailingSlash ? '$directoryPath/' : directoryPath;

          await testCodeBuildHook(
            mainMethod: hook.main,
            targetOS: OS.linux,
            targetArchitecture: Architecture.x64,
            userDefines: PackageUserDefines(
              workspacePubspec: PackageUserDefinesSource(
                defines: {'prebuilt_assets_dir': configuredPath},
                basePath: workspace.uri,
              ),
            ),
            check: (input, output) async {
              expect(output.dependencies, [library.uri]);
              expect(output.assets.code, hasLength(1));
              final asset = output.assets.code.single;
              expect(
                asset.id,
                'package:flutter_libepiccash/'
                'src/epic_cash_wallet_bindings.g.dart',
              );
              expect(asset.linkMode, isA<DynamicLoadingBundled>());
              expect(
                asset.file,
                input.outputDirectory.resolve('libepic_cash_wallet.so'),
              );
              expect(await File.fromUri(asset.file!).readAsBytes(), [
                0,
                1,
                2,
                3,
              ]);
            },
          );
        },
      );
    }
  }

  for (final target in {
    Architecture.arm: 'armv7-linux-androideabi',
    Architecture.arm64: 'aarch64-linux-android',
    Architecture.x64: 'x86_64-linux-android',
  }.entries) {
    test(
      'bundles the prebuilt Android C++ runtime for ${target.key}',
      () async {
        final wallet = await File.fromUri(
          prebuiltDirectory.uri.resolve(
            'libepic_cash_wallet-${target.value}.so',
          ),
        ).writeAsBytes([1, 2, 3]);
        final runtime = await File.fromUri(
          prebuiltDirectory.uri.resolve('libc++_shared-${target.value}.so'),
        ).writeAsBytes([4, 5, 6]);

        await testCodeBuildHook(
          mainMethod: hook.main,
          targetOS: OS.android,
          targetArchitecture: target.key,
          userDefines: PackageUserDefines(
            workspacePubspec: PackageUserDefinesSource(
              defines: {'prebuilt_assets_dir': 'native assets/epic cash'},
              basePath: workspace.uri,
            ),
          ),
          check: (input, output) async {
            expect(
              output.dependencies,
              unorderedEquals([wallet.uri, runtime.uri]),
            );
            expect(output.assets.code, hasLength(2));
            final assets = {
              for (final asset in output.assets.code)
                asset.file!.pathSegments.last: asset,
            };
            expect(
              assets.keys,
              unorderedEquals(['libepic_cash_wallet.so', 'libc++_shared.so']),
            );
            for (final asset in assets.values) {
              expect(asset.linkMode, isA<DynamicLoadingBundled>());
              expect(
                asset.file,
                input.outputDirectory.resolve(asset.file!.pathSegments.last),
              );
            }
            final runtimeAsset = assets['libc++_shared.so']!;
            expect(
              runtimeAsset.id,
              'package:flutter_libepiccash/libc++_shared.so',
            );
            expect(await File.fromUri(runtimeAsset.file!).readAsBytes(), [
              4,
              5,
              6,
            ]);
            expect(
              await File.fromUri(assets['libepic_cash_wallet.so']!.file!)
                  .readAsBytes(),
              [1, 2, 3],
            );
          },
        );
      },
    );
  }

  test('reports the missing prebuilt Android C++ runtime filename', () async {
    await File.fromUri(
      prebuiltDirectory.uri.resolve(
        'libepic_cash_wallet-aarch64-linux-android.so',
      ),
    ).writeAsBytes([1, 2, 3]);

    await expectLater(
      testCodeBuildHook(
        mainMethod: hook.main,
        targetOS: OS.android,
        targetArchitecture: Architecture.arm64,
        userDefines: PackageUserDefines(
          workspacePubspec: PackageUserDefinesSource(
            defines: {'prebuilt_assets_dir': 'native assets/epic cash'},
            basePath: workspace.uri,
          ),
        ),
        check: (_, _) => fail('The missing runtime must fail the build.'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('libc++_shared-aarch64-linux-android.so'),
            contains('NDK used to build the wallet library'),
          ),
        ),
      ),
    );
  });
}
