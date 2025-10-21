# `flutter_libepiccash`
## Dependencies
### Rust
Install Rust: https://www.rust-lang.org/tools/install
```sh
rustup install 1.81
rustup default 1.81
```

### `cargo-ndk`
```sh
cargo install cargo-ndk
```

## Android
### Add targets to rust
```sh
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android
```

### Install dependencies
```sh
# https://github.com/EpicCash/epic/blob/master/doc/build.md#requirements
sudo apt install build-essential \
	cmake \
	git \
	libgit2-dev \
	clang \
	debhelper \
	libclang-dev \
	libncurses5-dev \
	libncursesw5-dev \
	zlib1g-dev \
	pkg-config \
	llvm \
	cargo \
	rustc \
	opencl-headers \
	libssl-dev \
	ocl-icd-opencl-dev \
	libc6-dev-i386
```

### Build
```sh
cd scripts/android
./install_ndk.sh
./build_all.sh
```

## iOS
### Add targets to rust
```sh
rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim
```

### Install dependencies
```sh
cargo install cargo-lipo
cargo install cbindgen
```

### Build
```sh
cd scripts/ios
./build_all
```

## Windows
### Dependencies
Run `scripts/windows/deps.sh` in WSL (may need to alter permissions like with `chmod +x *.sh`) to install `x86_64-w64-mingw32-gcc` and `clang` or run
```sh
sudo apt-get install clang gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64
```

### Building for Windows
Run `scripts/windows/build_all.sh` in WSL (Ubuntu 20.04 on WSL2 has been tested)

Libraries will be output to `scripts/windows/build`

### Building on Windows
Perl is required for building on Windows.  Strawberry Perl has been tested working.

Run `build_all.ps1` in Powershell.  This is not confirmed working and may need work eg. may need some missing dependencies added but has been included as a starting point or example for Windows developers.

## Contributing
### Regenerate FFI Bindings (ffigen)

The Dart bindings in `lib/src/bindings_generated.dart` are auto-generated from the C header produced by the Rust crate. If you change the Rust FFI surface, regenerate as follows from `flutter_libepiccash/`:

1) Ensure the C header exists/updated with cbindgen:
- Install cbindgen, `cargo install cbindgen`.
- Generate header: `cbindgen rust -c rust/cbindgen.toml -o rust/target/epic_cash_wallet.h`.

2) Generate Dart bindings with ffigen:
- Install Dart SDK and `ffigen` dev dependency.
- Fetch deps: `dart pub get`.
- Generate: `dart run ffigen --config ffigen.yaml`.

Notes:
- If ffigen cannot find LLVM/Clang, adjust `llvm-path` in `ffigen.yaml` or install LLVM (e.g., `sudo apt install llvm clang`).
- Ensure the Rust library’s exported C functions match those listed under `functions.include` in `ffigen.yaml`.
