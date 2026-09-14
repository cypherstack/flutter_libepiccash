# flutter_libepiccash

Dart bindings for the Epic Cash wallet library. The Rust library is built and
bundled through Flutter Native Assets, using Flutter's standard asset bundling
instead of the former plugin packaging and platform-specific download scripts.

## Requirements

- Flutter 3.47 or newer
- Dart 3.13 or newer
- For source builds: Rust 1.89.0 through `rustup` (selected by
  [`rust/rust-toolchain.toml`](rust/rust-toolchain.toml))
- The normal native build tools for the target platform: Xcode on Apple
  platforms, the Android NDK for Android, a C/C++ toolchain and CMake on
  Linux, or Visual Studio Build Tools plus Perl on Windows

The example projects target Android API 24, iOS 15, and macOS 12 or newer.

## Build from source

Source builds are the default. Once Rust and the platform toolchain are
available, use the package like any other Flutter dependency:

```sh
flutter pub get
flutter run
```

Flutter runs `hook/build.dart`, compiles the Rust crate for the application's
target architecture, and bundles the resulting dynamic library. The first
build can take several minutes because OpenSSL, RandomX, and the wallet
dependencies are compiled from source. Cargo and Flutter cache subsequent
builds.

## Migrate an existing application

Remove the former Epic Cash plugin registrants, podspec references, copied
libraries, and package-specific CMake copy rules. Keep Flutter's standard
Native Assets installation rules in desktop applications; see the example's
[`windows/CMakeLists.txt`](example/windows/CMakeLists.txt) and
[`linux/CMakeLists.txt`](example/linux/CMakeLists.txt).

Android applications must declare Internet access in
`android/app/src/main/AndroidManifest.xml`, directly inside `<manifest>`, so
release builds can connect to the node and Epicbox. The removed plugin manifest
previously supplied this permission:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## Use prebuilt native assets

To download a release, copy its manifest URL and SHA-256 into the application's
root `pubspec.yaml` (workspace root for pub workspaces):

```yaml
hooks:
  user_defines:
    flutter_libepiccash:
      native_build: prebuilt
      prebuilt_manifest_url: https://github.com/cypherstack/flutter_libepiccash/releases/download/native-YOUR-RELEASE/manifest.json
      prebuilt_manifest_sha256: "REPLACE_WITH_RELEASE_MANIFEST_SHA256"
```

Use the package revision named in the release. The hook verifies the manifest,
native source fingerprint, deployment minimum, and each library's size and hash,
including Android's C++ runtime. Invalid or missing assets fail the build.
Downloads require public HTTPS and dynamic linking without sanitizers. Rust is
not needed, but Flutter's normal application build tools are still required.

Downloads live in Flutter's hook output. Each hook run fetches fresh files;
incremental builds can reuse the output until `flutter clean` removes it.
Omit the settings or use `native_build: source` to compile Rust.

Prebuilts require Android API 24, iOS 15, or macOS 12. Linux deployments must meet
the target's `minimum_glibc_version` in the manifest; musl is unsupported. Windows
releases cover x64.

## Publish native prebuilts

Push a new `native-*` tag (for example `native-0.0.1-1`) or `vX.Y.Z` tag. The
release workflow builds all eleven targets and publishes the libraries, header,
checksums, and pinned manifest together. Release notes include consumer settings.
Existing releases are not overwritten; manual branch runs only upload workflow
artifacts. Older releases without a manifest cannot use download mode.

Manifest generation uses the existing build recipes. To generate one locally,
place all target-named libraries and Android runtimes built from the current
revision in `artifacts/`, then run from the repository root:

```sh
flutter pub get
dart --packages=.dart_tool/package_config.json tool/prebuilt_manifest.dart artifacts
```

Linux inspection requires `readelf`. Upload the manifest and libraries together.
Resolver tests run with the existing `flutter test` suite and CI.

## Regenerate and verify the ABI

The checked-in header is the ABI source for generated Dart declarations:

```sh
dart run ffigen --config ffigen.yaml
flutter test
```

After intentionally changing an exported Rust function, regenerate the C
header from the Rust crate before running FFIgen:

```sh
cargo install cbindgen --version 0.24.3
cd rust
cbindgen --config cbindgen.toml \
  --crate epic-cash-wallet \
  --output include/epic_cash_wallet.h
```

`test/ffi_abi_test.dart` checks exported Rust names and arities against the
header. `test/native_assets_smoke_test.dart` loads the bundled native asset,
calls the mnemonic function, and exercises Rust-owned string deallocation.
