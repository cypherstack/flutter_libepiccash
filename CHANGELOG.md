## Unreleased

- Require Flutter 3.47 and Dart 3.13.
- Build and bundle the Rust dynamic library with Flutter Native Assets.
- Replace runtime `DynamicLibrary` lookup code with generated `@Native`
  bindings.
- Add the Rust-owned `epic_cash_string_free` ABI and use it for every returned
  string.
- Remove the legacy Flutter plugin classes, podspecs, CMake targets, copied
  binaries, and platform build/download scripts.
- Add target-named prebuilt asset support, ABI/smoke tests, and native artifact
  release automation.

## 0.0.1

- Initial release.
