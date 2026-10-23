## Unreleased

- Pin Rust 1.99.1. Earlier toolchains strip Apple dynamic libraries with a
  misaligned `__LINKEDIT` string pool, which iOS 27 and macOS 27 refuse to
  load.
- Require Flutter 3.47 and Dart 3.13.
- Build and bundle the Rust dynamic library with Flutter Native Assets.
- Replace runtime `DynamicLibrary` lookup code with generated `@Native`
  bindings.
- Add the Rust-owned `epic_cash_string_free` ABI and use it for every returned
  string.
- Remove the legacy Flutter plugin classes, podspecs, CMake targets, copied
  binaries, and platform build/download scripts.
- Build the native library with [dnix](https://github.com/cypherstack/dnix).
  By default the build hook downloads the library of the release `dnix.lock`
  names and verifies its SHA-256; the `build` user define selects `source` or
  `dev`, which build with Nix on Linux or an Apple Silicon Mac. The
  `native_build`, `prebuilt_manifest_url`, and `prebuilt_manifest_sha256`
  user defines are no longer read. Every change is built on four hosts, which
  must produce the bytes the lock records.
- Build the Windows library for the GNU ABI; it imports only system DLLs.
- Link the C++ runtime statically on Android, so `libc++_shared.so` no longer
  ships beside the library.
- Add ABI and smoke tests.

## 0.0.1

- Initial release.
