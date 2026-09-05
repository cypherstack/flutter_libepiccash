# flutter_libepiccash

Dart bindings for the Epic Cash wallet library. The Rust library is built and
bundled through Flutter Native Assets; applications do not need plugin
registrants, podspecs, CMake copy rules, or platform-specific download scripts.

## Requirements

- Flutter 3.47 or newer
- Dart 3.13 or newer
- Rust 1.89.0 through `rustup` (selected by
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

## Use prebuilt native assets

A consuming application can bypass the Rust build with a directory of trusted
prebuilt libraries. Add this top-level configuration to the application's
`pubspec.yaml`:

```yaml
hooks:
  user_defines:
    flutter_libepiccash:
      prebuilt_assets_dir: native-assets/epic-cash/
```

Relative paths are resolved from that `pubspec.yaml`. The directory only
needs the files for the application's build targets, using these exact names:

| Platform | Filename |
| --- | --- |
| Android arm64 | `libepic_cash_wallet-aarch64-linux-android.so` |
| Android armv7 | `libepic_cash_wallet-armv7-linux-androideabi.so` |
| Android x64 | `libepic_cash_wallet-x86_64-linux-android.so` |
| iOS device arm64 | `libepic_cash_wallet-aarch64-apple-ios.dylib` |
| iOS simulator arm64 | `libepic_cash_wallet-aarch64-apple-ios-sim.dylib` |
| iOS simulator x64 | `libepic_cash_wallet-x86_64-apple-ios.dylib` |
| Linux arm64 | `libepic_cash_wallet-aarch64-unknown-linux-gnu.so` |
| Linux x64 | `libepic_cash_wallet-x86_64-unknown-linux-gnu.so` |
| macOS arm64 | `libepic_cash_wallet-aarch64-apple-darwin.dylib` |
| macOS x64 | `libepic_cash_wallet-x86_64-apple-darwin.dylib` |
| Windows x64 | `libepic_cash_wallet-x86_64-pc-windows-msvc.dll` |

Android targets also need the matching `libc++_shared-<rust-target>.so` from the
same release alongside the wallet library, for example
`libc++_shared-aarch64-linux-android.so`. The hook bundles this C++ runtime as
`libc++_shared.so`; Android does not provide it as a system library.

Only use artifacts built from this Native Assets ABI. In particular, older
artifacts that do not export `epic_cash_string_free` are incompatible. The
release workflow publishes target-named libraries and a `checksums.txt` file
for verification.

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
