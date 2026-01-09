#!/usr/bin/env bash
set -e

# Prevent caching of build artifacts.
if [ -d "build" ]; then
    rm -rf build/
fi
# Prevent caching for example app.
if [ -d "../../example/ios/Pods" ]; then
    rm -rf ../../example/ios/Pods/
fi
if [ -f "../../example/ios/Podfile.lock" ]; then
    rm -f ../../example/ios/Podfile.lock
fi
# Prevent caching the library for Stack Wallet (if applicable).
if [ -d "../../../../ios/Pods" ]; then
    rm -rf ../../../../ios/Pods/
fi
if [ -f "../../../../ios/Podfile.lock" ]; then
    rm -f ../../../../ios/Podfile.lock
fi

mkdir build
echo ''$(git log -1 --pretty=format:"%H")' '$(date) >> build/git_commit_version.txt
VERSIONS_FILE=../../lib/git_versions.dart
EXAMPLE_VERSIONS_FILE=../../lib/git_versions_example.dart
if [ ! -f "$VERSIONS_FILE" ]; then
    cp $EXAMPLE_VERSIONS_FILE $VERSIONS_FILE
fi
COMMIT=$(git log -1 --pretty=format:"%H")
OS="IOS"
sed -i '' '/\/\*${OS}_VERSION/c\'$'\n''/\*${OS}_VERSION\*\/ const ${OS}_VERSION = "'"$COMMIT"'";' "$VERSIONS_FILE"
cp -r ../../rust build/rust
cd build/rust

rustup target add aarch64-apple-ios

# Build for iOS device only.
cp target/epic_cash_wallet.h libepic_cash_wallet.h

export IPHONEOS_DEPLOYMENT_TARGET=15.0
export RUSTFLAGS="-C link-arg=-mios-version-min=15.0"
cargo build --release --target aarch64-apple-ios

# Generate the C header file using cbindgen.
cbindgen --config cbindgen.toml --crate epic-cash-wallet --output target/epic_cash_wallet.h

# Copy the generated header file.
cp target/epic_cash_wallet.h libepic_cash_wallet.h
cp target/epic_cash_wallet.h ../../../../ios/Classes/FlutterLibepiccashPlugin.h

# Find and merge librandomx.a with libepic_cash_wallet.a.
RANDOMX_LIB=$(find target/aarch64-apple-ios/release/build -name "librandomx.a" | head -n 1)
if [ -f "$RANDOMX_LIB" ]; then
    echo "Found RandomX library at: $RANDOMX_LIB"
    # Merge the libraries using libtool
    libtool -static -o target/aarch64-apple-ios/release/libepic_cash_wallet_combined.a \
        target/aarch64-apple-ios/release/libepic_cash_wallet.a \
        "$RANDOMX_LIB"
    MAIN_LIB=target/aarch64-apple-ios/release/libepic_cash_wallet_combined.a
else
    echo "Warning: librandomx.a not found, using libepic_cash_wallet.a only"
    MAIN_LIB=target/aarch64-apple-ios/release/libepic_cash_wallet.a
fi

# Move files to iOS project (device-only, no XCFramework needed).
inc=../../../../ios/include
libs=../../../../ios/libs

rm -rf ${inc} ${libs}
mkdir -p ${inc} ${libs}

cp libepic_cash_wallet.h ${inc}/
cp "$MAIN_LIB" ${libs}/libepic_cash_wallet.a