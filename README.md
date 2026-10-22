# flutter_libepiccash

Dart bindings for the Epic Cash wallet library. The Rust library is built and
bundled through Flutter Native Assets.

## Requirements

- Flutter 3.47 or newer, Dart 3.13 or newer. Nothing else: the build hook
  downloads the library built for this version and checks its hash.
- To build the library yourself: Nix on Linux or an Apple Silicon Mac, and
  Xcode 27.0 for the Apple targets. OpenSSL and RandomX are compiled from
  source inside that build.

The example projects target Android API 24, iOS 15, and macOS 12 or newer.

## Native library

The hook obtains the Rust library in one of three modes, chosen with the
`build` user define in the consuming app's root `pubspec.yaml` (the workspace
root for pub workspaces), or for this checkout with a `.dnix-build` file
holding the mode:

```yaml
hooks:
  user_defines:
    flutter_libepiccash:
      build: prebuilt   # the default; or source, or dev
```

- `prebuilt` downloads the library of the release `dnix.lock` names and
  verifies it against the hash recorded there. A mismatch is an error, never
  a fallback. Downloads are cached by hash and need public HTTPS.
- `source` builds the library with Nix, the same build CI uses, and verifies
  it against the same hash.
- `dev` builds with Nix but skips the Xcode pin and the hash check, for
  working on the Rust code. The hook notices a `.dnix-build` file from its
  next run on, so touch `dnix.json` after creating it.

Only dynamic libraries are provided, for Android API 24, iOS 15, macOS 12,
and glibc 2.28 at minimum, on armv7, arm64, and x64 Android, arm64 and x64
macOS, iOS devices and simulators, x64 and arm64 Linux, and x64 Windows.
The Windows library is built for the GNU ABI (`x86_64-pc-windows-gnullvm`,
MinGW-w64 as zig builds it): RandomX's C++ build assumes Microsoft's
compiler and assembler on the MSVC side, which no other host can provide,
while its GCC-style build works unchanged. The DLL links its runtime
pieces statically and imports only system DLLs, so it needs no Visual C++
redistributable, and a Flutter application loads it like any other. There
is no arm64 Windows library: the dependency tree still carries `winapi`
0.2, which knows no arm64. The Android libraries link the C++ runtime
statically, so no `libc++_shared.so` ships beside them. The floors, the
Rust and Xcode versions, and the location of the Rust workspace live in
`dnix.json`.

### Releases

`dnix.lock` records the hash of every library the Rust source builds to and
names the GitHub release, `native-<release>`, that holds those bytes. After
changing the Rust code, run `dart tool/update_lock.dart` on a Mac with Nix
and Xcode 27.0 and commit the lock with the change; without a Mac, push and
copy the lock CI prints once every host is green. CI
(`.github/workflows/native.yml`) builds on four hosts, fails if any host or
the lock disagrees, and publishes the release when the lock reaches the
default branch. Nothing is committed by CI, and old releases stay.

Anyone can rebuild one platform with Nix and compare:
`dart tool/verify_release.dart linux` (or android, macos, ios, or a target
triple), on Windows inside WSL2 for the non-Apple platforms. The build
comes from the shared [dnix](https://github.com/cypherstack/dnix) package,
whose documentation explains how the bytes stay identical across hosts.

### Tests

`flutter test` runs the Dart tests against the bundled library, and
`cargo test --locked --lib` in `rust` runs the Rust unit tests. Before the
lock's release is published, or to test local Rust changes, the Dart tests
need the library built from source: `echo dev > .dnix-build` with Nix
installed (`source` to also check the hash).

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
```## Regenerate and verify the ABI

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
