# `flutter_libepiccash`
## Submodules
Initialize submodules:
```sh
git submodule update --init --recursive
```

## Dependencies
### Rust
Install Rust: https://www.rust-lang.org/tools/install
```sh
rustup install 1.67.1
rustup default 1.67.1
```

### `cargo-ndk`
```sh
cargo install cargo-ndk
```

# Android
## Add targets to rust
```sh
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android
```

## Install dependencies
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

## Build
```sh
cd scripts/android
./install_ndk.sh
./build_all.sh
```

# iOS
## Add targets to rust
```sh
rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim
```

## Install dependencies
```sh
cargo install cargo-lipo
cargo install cbindgen
```

## Build
Builds are automatically triggered upon a Flutter build using [cargokit](https://github.com/irondash/cargokit) (see [this guide](https://matejknopp.com/post/flutter_plugin_in_rust_with_no_prebuilt_binaries/)).

# Windows
## Dependencies
Run `scripts/windows/deps.sh` in WSL (may need to alter permissions like with `chmod +x *.sh`) to install `x86_64-w64-mingw32-gcc` and `clang` or run
```sh
sudo apt-get install clang gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64
```

## Building on Windows
`build_all.ps1` is not confirmed working and may need work eg. may need some missing dependencies added but has been included as a starting point or example for Windows users

# Development
## Cargokit
Cargokit may be updated using:
```sh
git subtree pull --prefix cargokit https://github.com/irondash/cargokit.git main --squash
```
in the plugin root.

## Bindings generation
To generate `epic_cash_wallet.h` C bindings for Rust, `cbindgen --config cbindgen.toml --crate epic_cash_wallet --output target/epic_cash_wallet.h` or `cargo build` in `rust` to produce headers according to `build.rs`.

[//]: # (To generate `epic_cash_bindings_generated.dart` Dart bindings for C, `flutter pub run ffigen --config ffigen.yaml`.)
