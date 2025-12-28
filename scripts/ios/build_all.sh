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
# Prevent caching the library for Stack Wallet (if applicable).
if [ -f "../../../../ios/Pods" ]; then
    rm -rf ../../../../ios/Pods/
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

rustup target add aarch64-apple-ios x86_64-apple-ios

# building
cp target/epic_cash_wallet.h libepic_cash_wallet.h

export IPHONEOS_DEPLOYMENT_TARGET=15.0
export RUSTFLAGS="-C link-arg=-mios-version-min=15.0"
cargo build --release --target aarch64-apple-ios
#cargo lipo --release

# Find and merge librandomx.a with libepic_cash_wallet.a
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

# moving files to the ios project
inc=../../../../ios/include
libs=../../../../ios/libs

rm -rf ${inc} ${libs}

mkdir ${inc}
mkdir ${libs}

cp libepic_cash_wallet.h ${inc}
cp "$MAIN_LIB" ${libs}/libepic_cash_wallet.a