import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

const _assetName = 'src/epic_cash_wallet_bindings.g.dart';
const _prebuiltAssetsDirectory = 'prebuilt_assets_dir';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final prebuiltDirectory = input.userDefines.path(_prebuiltAssetsDirectory);
    if (prebuiltDirectory != null) {
      await _bundlePrebuilt(input, output, prebuiltDirectory);
      return;
    }

    // Cargo's dep-info lists Rust sources but omits these build inputs.
    output.dependencies.addAll([
      for (final path in [
        'rust/Cargo.toml',
        'rust/Cargo.lock',
        'rust/rust-toolchain.toml',
      ])
        input.packageRoot.resolve(path),
    ]);

    await RustBuilder(
      assetName: _assetName,
      cratePath: 'rust',
      extraCargoBuildArgs: const ['--locked'],
      extraCargoEnvironmentVariables: {
        ..._macOsRustToolchainEnvironment(),
        ..._cargoEnvironment(input.config.code),
      },
    ).run(input: input, output: output);

    if (input.config.code.targetOS == OS.android) {
      await _bundleAndroidRuntime(input, output);
    }
  });
}

Future<void> _bundlePrebuilt(
  BuildInput input,
  BuildOutputBuilder output,
  Uri prebuiltDirectory,
) async {
  final code = input.config.code;
  final directory = Directory.fromUri(prebuiltDirectory).uri;
  final source = File.fromUri(directory.resolve(_prebuiltFileName(code)));
  if (!source.existsSync()) {
    throw StateError(
      'No prebuilt Epic Cash library for '
      '${code.targetOS}/${code.targetArchitecture}: ${source.path}',
    );
  }

  await _bundleFile(
    input,
    output,
    source: source,
    assetName: _assetName,
    fileName: _bundledFileName(code.targetOS),
  );
  if (code.targetOS == OS.android) {
    await _bundleAndroidRuntime(input, output, prebuiltDirectory: directory);
  }
}

Future<void> _bundleAndroidRuntime(
  BuildInput input,
  BuildOutputBuilder output, {
  Uri? prebuiltDirectory,
}) async {
  final code = input.config.code;
  final target = _rustTarget(code);
  final File source;
  if (prebuiltDirectory != null) {
    source = File.fromUri(
      prebuiltDirectory.resolve('libc++_shared-$target.so'),
    );
  } else {
    final toolchainRoot = File.fromUri(code.cCompiler!.compiler).parent.parent;
    source = File.fromUri(
      toolchainRoot.uri.resolve(
        'sysroot/usr/lib/${_androidSysrootTarget(target)}/libc++_shared.so',
      ),
    );
  }
  if (!source.existsSync()) {
    throw StateError(
      'No ${prebuiltDirectory == null ? 'NDK' : 'prebuilt'} Android C++ runtime '
      'for $target: ${source.path}. '
      'Use libc++_shared.so from the NDK used to build the wallet library.',
    );
  }

  await _bundleFile(
    input,
    output,
    source: source,
    assetName: 'libc++_shared.so',
    fileName: 'libc++_shared.so',
  );
}

Future<void> _bundleFile(
  BuildInput input,
  BuildOutputBuilder output, {
  required File source,
  required String assetName,
  required String fileName,
}) async {
  output.dependencies.add(source.uri);

  // Every architecture of one asset must have the same final basename. The
  // release filenames contain target details, so copy the selected file to a
  // canonical name in the hook output before handing it to Flutter.
  final bundled = File.fromUri(input.outputDirectory.resolve(fileName));
  await bundled.parent.create(recursive: true);
  await source.copy(bundled.path);

  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: assetName,
      linkMode: DynamicLoadingBundled(),
      file: bundled.uri,
    ),
  );
}

Map<String, String> _macOsRustToolchainEnvironment() {
  if (!Platform.isMacOS) {
    return const {};
  }

  // Preserve native_toolchain_rust's removal of Xcode-injected tool paths.
  final paths = (Platform.environment['PATH'] ?? '')
      .split(':')
      .where((path) => !path.contains('Contents/Developer/'))
      .toList();
  if (paths.any((path) => File('$path/rustc').existsSync())) {
    return const {};
  }

  // Homebrew can expose only rustup on PATH. Its resolved installation also
  // contains the rustc/cargo proxies needed by `rustup run ... cargo build`.
  final homeDirectory = Platform.environment['HOME'];
  for (final path in [
    ...paths,
    if (homeDirectory != null) '$homeDirectory/.cargo/bin',
  ]) {
    final rustup = File('$path/rustup');
    if (!rustup.existsSync()) {
      continue;
    }
    final toolchainBin = File(rustup.resolveSymbolicLinksSync()).parent.path;
    if (File('$toolchainBin/rustc').existsSync()) {
      return {
        'PATH': [...paths, toolchainBin].join(':'),
      };
    }
  }
  return const {};
}

Map<String, String> _cargoEnvironment(CodeConfig code) {
  if (code.targetOS == OS.android) {
    return _androidCargoEnvironment(code);
  }
  if (code.targetOS == OS.iOS) {
    // Flutter 3.47 currently reports iOS 13 to native-assets hooks even when
    // the consuming Xcode project has a newer deployment target. Keep the
    // native library aligned with this package's documented iOS 15 minimum.
    final targetVersion = code.iOS.targetVersion < 15
        ? 15
        : code.iOS.targetVersion;
    return {'IPHONEOS_DEPLOYMENT_TARGET': '$targetVersion.0'};
  }
  if (code.targetOS == OS.macOS) {
    // Build for the package floor. A library built for an older deployment
    // target remains usable when the consuming application requires newer.
    return {'MACOSX_DEPLOYMENT_TARGET': '12.0'};
  }
  return const {};
}

Map<String, String> _androidCargoEnvironment(CodeConfig code) {
  final compiler = code.cCompiler;
  if (compiler == null) {
    throw StateError('Flutter did not provide an Android NDK compiler.');
  }

  final api = code.android.targetNdkApi;
  if (api < 24) {
    throw UnsupportedError(
      'Flutter 3.47 requires Android API 24 or newer; received API $api.',
    );
  }

  final target = _rustTarget(code);
  final environmentTarget = target.replaceAll('-', '_');
  final ndkTarget = target == 'armv7-linux-androideabi'
      ? 'armv7a-linux-androideabi'
      : target;
  final sysrootTarget = _androidSysrootTarget(target);

  final compilerDirectory = File.fromUri(compiler.compiler).parent;
  final executableSuffix = Platform.isWindows ? '.cmd' : '';
  final clang = File(
    '${compilerDirectory.path}${Platform.pathSeparator}'
    '$ndkTarget$api-clang$executableSuffix',
  );
  final clangPp = File(
    '${compilerDirectory.path}${Platform.pathSeparator}'
    '$ndkTarget$api-clang++$executableSuffix',
  );
  if (!clang.existsSync() || !clangPp.existsSync()) {
    throw StateError(
      'The configured Android NDK does not contain API $api compiler '
      'wrappers for $target.',
    );
  }

  final toolchainRoot = compilerDirectory.parent;
  final sysroot = Directory.fromUri(toolchainRoot.uri.resolve('sysroot/'));
  final targetInclude = Directory.fromUri(
    sysroot.uri.resolve('usr/include/$sysrootTarget/'),
  );

  // bin/<host>/prebuilt/llvm/toolchains/<ndk-root>
  var ndkRoot = compilerDirectory;
  for (var level = 0; level < 5; level++) {
    ndkRoot = ndkRoot.parent;
  }

  return {
    // native_toolchain_rust 1.0.6 currently defaults these entries to API 35.
    // Override them with Flutter's consuming application's actual minimum API.
    'CC_$environmentTarget': clang.path,
    'CXX_$environmentTarget': clangPp.path,
    'CARGO_TARGET_${environmentTarget.toUpperCase()}_LINKER': clang.path,
    'BINDGEN_EXTRA_CLANG_ARGS_$environmentTarget':
        '--sysroot=${_clangPathArgument(sysroot.path)} '
        '-I${_clangPathArgument(targetInclude.path)}',
    'ANDROID_NDK_HOME': ndkRoot.path,
    // CMake-based Rust dependencies discover the NDK through this variable.
    'ANDROID_NDK_ROOT': ndkRoot.path,
  };
}

String _androidSysrootTarget(String target) =>
    target == 'armv7-linux-androideabi' ? 'arm-linux-androideabi' : target;

// Bindgen parses this environment variable with shlex, including on Windows.
// Normalize Windows separators and quote paths to preserve spaces and quotes.
String _clangPathArgument(String path) =>
    "'${path.replaceAll(r'\', '/').replaceAll("'", r"'\''")}'";

String _rustTarget(CodeConfig code) =>
    switch ((code.targetOS, code.targetArchitecture)) {
      (OS.android, Architecture.arm) => 'armv7-linux-androideabi',
      (OS.android, Architecture.arm64) => 'aarch64-linux-android',
      (OS.android, Architecture.x64) => 'x86_64-linux-android',
      (OS.iOS, Architecture.arm64)
          when code.iOS.targetSdk == IOSSdk.iPhoneSimulator =>
        'aarch64-apple-ios-sim',
      (OS.iOS, Architecture.arm64) => 'aarch64-apple-ios',
      (OS.iOS, Architecture.x64) => 'x86_64-apple-ios',
      (OS.linux, Architecture.arm64) => 'aarch64-unknown-linux-gnu',
      (OS.linux, Architecture.x64) => 'x86_64-unknown-linux-gnu',
      (OS.macOS, Architecture.arm64) => 'aarch64-apple-darwin',
      (OS.macOS, Architecture.x64) => 'x86_64-apple-darwin',
      (OS.windows, Architecture.arm64) => 'aarch64-pc-windows-msvc',
      (OS.windows, Architecture.x64) => 'x86_64-pc-windows-msvc',
      _ => throw UnsupportedError(
        'Unsupported native target: '
        '${code.targetOS}/${code.targetArchitecture}',
      ),
    };

String _prebuiltFileName(CodeConfig code) {
  final target = _rustTarget(code);
  final extension = switch (code.targetOS) {
    OS.android || OS.linux => 'so',
    OS.iOS || OS.macOS => 'dylib',
    OS.windows => 'dll',
    _ => throw UnsupportedError('Unsupported OS: ${code.targetOS}'),
  };
  return 'libepic_cash_wallet-$target.$extension';
}

String _bundledFileName(OS os) => switch (os) {
  OS.android || OS.linux => 'libepic_cash_wallet.so',
  OS.iOS || OS.macOS => 'libepic_cash_wallet.dylib',
  OS.windows => 'epic_cash_wallet.dll',
  _ => throw UnsupportedError('Unsupported OS: $os'),
};
